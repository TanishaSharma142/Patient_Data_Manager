// src/services/patientService.ts
import { PrismaClient, Patient } from '@prisma/client';
import { Decimal } from '@prisma/client/runtime/library';
import { getEncryption } from '../utils/encryption';
import { JWTPayload } from '../utils/jwt';

const prisma = new PrismaClient();

export interface CashEntryInput {
  entryDate?: string;
  amount?: string;
}

export interface PatientData {
  date?: string;
  patientName?: string;
  countryCode?: string;
  phone?: string;
  address?: string;
  package?: string;
  cash?: string;
  bank?: string;
  balance?: string;
  cashEntries?: CashEntryInput[];
}

export interface DecryptedCashEntry {
  id: string;
  entryDate: string;
  amount: string;
}

export interface DecryptedPatient {
  id: string;
  date?: string;
  patientName?: string;
  countryCode?: string;
  phone?: string;
  address?: string;
  package?: string;
  cash?: string;
  bank?: string;
  balance?: string;
  cashEntries?: DecryptedCashEntry[];
  createdAt: Date;
  updatedAt: Date;
}

type PatientWithCashEntries = Patient & {
  cashEntries?: {
    id: string;
    entryDate: Date;
    amount: Decimal;
  }[];
};

function parseDecimal(value: string | number | undefined | null): Decimal | null {
  if (value === undefined || value === null) return null;
  const normalized = typeof value === 'string' ? value.trim() : value.toString();
  if (normalized === '') return null;
  try {
    return new Decimal(normalized);
  } catch {
    return null;
  }
}

function formatDecimal(value: Decimal | null | undefined): string | undefined {
  if (!value) return undefined;
  return value.toString();
}

/**
 * Decrypt a patient record
 */
function decryptPatient(patient: PatientWithCashEntries): DecryptedPatient {
  const encryption = getEncryption();

  // safeDecrypt: if the stored value is empty/null, return undefined instead
  // of trying to decrypt an empty string (which causes "Invalid IV" crash)
  // Also catches decryption errors and returns undefined instead of throwing
  const safeDecrypt = (value: string | null | undefined): string | undefined => {
    if (!value || value.trim() === '') return undefined;
    try {
      return encryption.decrypt(value);
    } catch (error) {
      console.error('Decryption error for field:', (error as Error).message);
      return undefined;
    }
  };

  return {
    id: patient.id,
    date: patient.date ? patient.date.toISOString() : undefined,
    patientName: safeDecrypt(patient.patientNameEncrypted),
    countryCode: safeDecrypt(patient.countryCodeEncrypted),
    phone: safeDecrypt(patient.phoneEncrypted),
    address: safeDecrypt(patient.addressEncrypted),
    package: formatDecimal(patient.packageAmount),
    cash: formatDecimal(patient.cashTotal),
    bank: formatDecimal(patient.bankAmount),
    balance: formatDecimal(patient.balanceAmount),
    cashEntries: patient.cashEntries?.map(entry => ({
      id: entry.id,
      entryDate: entry.entryDate.toISOString(),
      amount: entry.amount.toString(),
    })),
    createdAt: patient.createdAt,
    updatedAt: patient.updatedAt
  };
}

/**
 * Encrypt patient string fields for storage
 */
function encryptPatientStrings(data: PatientData) {
  const encryption = getEncryption();

  // safeEncrypt: store NULL in DB for missing fields, never an empty string.
  // Empty string '' cannot be decrypted (no IV) and causes the crash.
  const safeEncrypt = (value: string | undefined | null): string | null => {
    if (value === undefined || value === null || value.trim() === '') return null;
    return encryption.encrypt(value);
  };

  return {
    patientNameEncrypted: safeEncrypt(data.patientName),
    countryCodeEncrypted: safeEncrypt(data.countryCode),
    phoneEncrypted:       safeEncrypt(data.phone),
    addressEncrypted:     safeEncrypt(data.address),
  };
}

/**
 * Filter patient data based on user role
 */
function filterPatientByRole(patient: DecryptedPatient, role: string): Partial<DecryptedPatient> {
  const filtered: Partial<DecryptedPatient> = {
    id: patient.id,
    createdAt: patient.createdAt,
    updatedAt: patient.updatedAt
  };

  switch (role) {
    case 'OWNER':
      // Owner sees everything
      return patient;
    
    case 'ACCOUNTANT':
      // Accountant sees: Package, Cash, Bank, Balance, Patient Name (no Phone/Address)
      return {
        ...filtered,
        date: patient.date,
        patientName: patient.patientName,
        package: patient.package,
        cash: patient.cash,
        bank: patient.bank,
        balance: patient.balance,
        cashEntries: patient.cashEntries
      };
    
    case 'SECRETARY':
      // Secretary sees: Date, Patient Name, Phone, Address, Package (no Financial)
      return {
        ...filtered,
        date: patient.date,
        patientName: patient.patientName,
        countryCode: patient.countryCode,
        phone: patient.phone,
        address: patient.address,
        package: patient.package
      };
    
    default:
      return filtered;
  }
}

/**
 * Create a new patient record
 */
export async function createPatient(data: PatientData): Promise<DecryptedPatient> {
  const encrypted = encryptPatientStrings(data);

  const parsedPackageAmount = parseDecimal(data.package) ?? new Decimal(0);
  const parsedBankAmount = parseDecimal(data.bank) ?? new Decimal(0);

  const cashEntries = (data.cashEntries ?? []).map(entry => ({
    entryDate: entry.entryDate ? new Date(entry.entryDate) : new Date(),
    amount: parseDecimal(entry.amount) ?? new Decimal(0),
  }));

  const cashTotal = cashEntries.reduce((sum, entry) => sum.plus(entry.amount), new Decimal(0));
  const resolvedCashTotal = cashEntries.length > 0
    ? cashTotal
    : parseDecimal(data.cash) ?? new Decimal(0);

  const patient = await prisma.patient.create({
    data: {
      ...encrypted,
      date: data.date ? new Date(data.date) : undefined,
      packageAmount: parsedPackageAmount,
      bankAmount: parsedBankAmount,
      cashTotal: resolvedCashTotal,
      balanceAmount: parsedPackageAmount.minus(resolvedCashTotal.plus(parsedBankAmount)),
      cashEntries: {
        create: cashEntries
      }
    },
    include: { cashEntries: true }
  });

  return decryptPatient(patient);
}

/**
 * Get a patient by ID (with role-based filtering)
 */
export async function getPatientById(id: string, userRole: string): Promise<Partial<DecryptedPatient> | null> {
  try {
    const patient = await prisma.patient.findUnique({
      where: { id },
      include: { cashEntries: true }
    });

    if (!patient) return null;

    try {
      const decrypted = decryptPatient(patient);
      return filterPatientByRole(decrypted, userRole);
    } catch (error) {
      console.error('Error decrypting patient:', id, (error as Error).message);
      // Return basic patient info without encrypted fields in case of decryption error
      return {
        id: patient.id,
        createdAt: patient.createdAt,
        updatedAt: patient.updatedAt
      };
    }
  } catch (error) {
    console.error('Error fetching patient:', error);
    throw error;
  }
}

/**
 * Get all patients (with role-based filtering)
 */
export async function getAllPatients(userRole: string): Promise<Partial<DecryptedPatient>[]> {
  try {
    const patients = await prisma.patient.findMany({
      orderBy: { createdAt: 'desc' },
      include: { cashEntries: true }
    });

    return patients.map(patient => {
      try {
        const decrypted = decryptPatient(patient);
        return filterPatientByRole(decrypted, userRole);
      } catch (error) {
        console.error('Error processing patient:', patient.id, (error as Error).message);
        // Return basic patient info without encrypted fields
        return {
          id: patient.id,
          createdAt: patient.createdAt,
          updatedAt: patient.updatedAt
        };
      }
    });
  } catch (error) {
    console.error('Error fetching patients:', error);
    throw error;
  }
}

/**
 * Update a patient record (with role-based field validation)
 */
export async function updatePatient(
  id: string,
  data: Partial<PatientData>,
  userRole: string
): Promise<Partial<DecryptedPatient> | null> {
  const patient = await prisma.patient.findUnique({
    where: { id },
    include: { cashEntries: true }
  });

  if (!patient) return null;

  // Validate that user can update requested fields
  validateUpdatePermissions(data, userRole);

  const enc = getEncryption();
  const safeEncrypt = (value: string | undefined | null): string | null => {
    if (value === undefined || value === null || value.trim() === '') return null;
    return enc.encrypt(value);
  };

  const updateData: any = {};
  if (data.date !== undefined)        updateData.date = data.date ? new Date(data.date) : null;
  if (data.patientName !== undefined) updateData.patientNameEncrypted = safeEncrypt(data.patientName);
  if (data.countryCode !== undefined) updateData.countryCodeEncrypted = safeEncrypt(data.countryCode);
  if (data.phone !== undefined)       updateData.phoneEncrypted       = safeEncrypt(data.phone);
  if (data.address !== undefined)     updateData.addressEncrypted     = safeEncrypt(data.address);

  const packageAmount = data.package !== undefined ? parseDecimal(data.package) : patient.packageAmount;
  const bankAmount = data.bank !== undefined ? parseDecimal(data.bank) : patient.bankAmount;

  if (data.package !== undefined) updateData.packageAmount = packageAmount;
  if (data.bank !== undefined) updateData.bankAmount = bankAmount;

  let cashTotal = patient.cashTotal ?? new Decimal(0);
  if (data.cashEntries !== undefined) {
    const cashEntries = data.cashEntries.map(entry => ({
      entryDate: entry.entryDate ? new Date(entry.entryDate) : new Date(),
      amount: parseDecimal(entry.amount) ?? new Decimal(0),
    }));
    cashTotal = cashEntries.reduce((sum, entry) => sum.plus(entry.amount), new Decimal(0));
    updateData.cashTotal = cashTotal;
    updateData.cashEntries = {
      deleteMany: {},
      create: cashEntries
    };
  }

  if (data.cash !== undefined) {
    cashTotal = parseDecimal(data.cash) ?? cashTotal;
    updateData.cashTotal = cashTotal;
  }

  const finalPackage = packageAmount ?? new Decimal(0);
  const finalBank = bankAmount ?? new Decimal(0);
  updateData.balanceAmount = finalPackage.minus(cashTotal.plus(finalBank));

  const updated = await prisma.patient.update({
    where: { id },
    data: updateData,
    include: { cashEntries: true }
  });

  const decrypted = decryptPatient(updated);
  return filterPatientByRole(decrypted, userRole);
}

/**
 * Delete a patient record
 */
export async function deletePatient(id: string): Promise<boolean> {
  await prisma.cashEntry.deleteMany({
    where: { patientId: id }
  });

  const result = await prisma.patient.delete({
    where: { id }
  });
  return !!result;
}

/**
 * Delete all patients (for panic wipe)
 */
export async function deleteAllPatients(): Promise<number> {
  return await prisma.$transaction(async tx => {
    await tx.cashEntry.deleteMany();
    const result = await tx.patient.deleteMany();
    return result.count;
  });
}

/**
 * Get all unencrypted patients for backup
 */
export async function getAllPatientsForBackup(): Promise<DecryptedPatient[]> {
  const patients = await prisma.patient.findMany({
    orderBy: { createdAt: 'desc' },
    include: { cashEntries: true }
  });

  return patients.map(decryptPatient);
}

/**
 * Validate that user can update these fields
 */
function validateUpdatePermissions(data: Partial<PatientData>, role: string): void {
  if (role === 'ACCOUNTANT') {
    // Accountant can only update financial fields and package
    const allowedFields = ['package', 'cash', 'bank', 'balance', 'cashEntries'];
    const requestedFields = Object.keys(data);
    
    for (const field of requestedFields) {
      if (!allowedFields.includes(field)) {
        throw new Error(`Accountant cannot update field: ${field}`);
      }
    }
  } else if (role === 'SECRETARY') {
    // Secretary can only update non-financial fields
    const allowedFields = ['date', 'patientName', 'countryCode', 'phone', 'address', 'package'];
    const requestedFields = Object.keys(data);
    
    for (const field of requestedFields) {
      if (!allowedFields.includes(field)) {
        throw new Error(`Secretary cannot update field: ${field}`);
      }
    }
  }
  // OWNER can update all fields
}