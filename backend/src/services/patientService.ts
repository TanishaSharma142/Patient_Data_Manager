// src/services/patientService.ts
import { PrismaClient, Patient } from '@prisma/client';
import { getEncryption } from '../utils/encryption';
import { JWTPayload } from '../utils/jwt';

const prisma = new PrismaClient();

export interface PatientData {
  date?: string;
  patientName?: string;
  phone?: string;
  address?: string;
  package?: string;
  cash?: string;
  bank?: string;
  balance?: string;
}

export interface DecryptedPatient {
  id: string;
  date?: string;
  patientName?: string;
  phone?: string;
  address?: string;
  package?: string;
  cash?: string;
  bank?: string;
  balance?: string;
  createdAt: Date;
  updatedAt: Date;
}

/**
 * Decrypt a patient record
 */
function decryptPatient(patient: Patient): DecryptedPatient {
  const encryption = getEncryption();
  
  return {
    id: patient.id,
    date: encryption.decrypt(patient.dateEncrypted),
    patientName: encryption.decrypt(patient.patientNameEncrypted),
    phone: encryption.decrypt(patient.phoneEncrypted),
    address: encryption.decrypt(patient.addressEncrypted),
    package: encryption.decrypt(patient.packageEncrypted),
    cash: encryption.decrypt(patient.cashEncrypted),
    bank: encryption.decrypt(patient.bankEncrypted),
    balance: encryption.decrypt(patient.balanceEncrypted),
    createdAt: patient.createdAt,
    updatedAt: patient.updatedAt
  };
}

/**
 * Encrypt patient data for storage
 */
function encryptPatientData(data: PatientData) {
  const encryption = getEncryption();
  
  return {
    dateEncrypted: data.date ? encryption.encrypt(data.date) : '',
    patientNameEncrypted: data.patientName ? encryption.encrypt(data.patientName) : '',
    phoneEncrypted: data.phone ? encryption.encrypt(data.phone) : '',
    addressEncrypted: data.address ? encryption.encrypt(data.address) : '',
    packageEncrypted: data.package ? encryption.encrypt(data.package) : '',
    cashEncrypted: data.cash ? encryption.encrypt(data.cash) : '',
    bankEncrypted: data.bank ? encryption.encrypt(data.bank) : '',
    balanceEncrypted: data.balance ? encryption.encrypt(data.balance) : ''
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
        balance: patient.balance
      };
    
    case 'SECRETARY':
      // Secretary sees: Date, Patient Name, Phone, Address, Package (no Financial)
      return {
        ...filtered,
        date: patient.date,
        patientName: patient.patientName,
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
  const encrypted = encryptPatientData(data);
  
  const patient = await prisma.patient.create({
    data: encrypted
  });
  
  return decryptPatient(patient);
}

/**
 * Get a patient by ID (with role-based filtering)
 */
export async function getPatientById(id: string, userRole: string): Promise<Partial<DecryptedPatient> | null> {
  const patient = await prisma.patient.findUnique({
    where: { id }
  });

  if (!patient) return null;

  const decrypted = decryptPatient(patient);
  return filterPatientByRole(decrypted, userRole);
}

/**
 * Get all patients (with role-based filtering)
 */
export async function getAllPatients(userRole: string): Promise<Partial<DecryptedPatient>[]> {
  const patients = await prisma.patient.findMany({
    orderBy: { createdAt: 'desc' }
  });

  return patients.map(patient => {
    const decrypted = decryptPatient(patient);
    return filterPatientByRole(decrypted, userRole);
  });
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
    where: { id }
  });

  if (!patient) return null;

  // Validate that user can update requested fields
  validateUpdatePermissions(data, userRole);

  // Only encrypt fields that are provided
  const updateData: any = {};
  
  if (data.date !== undefined) updateData.dateEncrypted = getEncryption().encrypt(data.date);
  if (data.patientName !== undefined) updateData.patientNameEncrypted = getEncryption().encrypt(data.patientName);
  if (data.phone !== undefined) updateData.phoneEncrypted = getEncryption().encrypt(data.phone);
  if (data.address !== undefined) updateData.addressEncrypted = getEncryption().encrypt(data.address);
  if (data.package !== undefined) updateData.packageEncrypted = getEncryption().encrypt(data.package);
  if (data.cash !== undefined) updateData.cashEncrypted = getEncryption().encrypt(data.cash);
  if (data.bank !== undefined) updateData.bankEncrypted = getEncryption().encrypt(data.bank);
  if (data.balance !== undefined) updateData.balanceEncrypted = getEncryption().encrypt(data.balance);

  const updated = await prisma.patient.update({
    where: { id },
    data: updateData
  });

  const decrypted = decryptPatient(updated);
  return filterPatientByRole(decrypted, userRole);
}

/**
 * Delete a patient record
 */
export async function deletePatient(id: string): Promise<boolean> {
  const result = await prisma.patient.delete({
    where: { id }
  });
  return !!result;
}

/**
 * Delete all patients (for panic wipe)
 */
export async function deleteAllPatients(): Promise<number> {
  const result = await prisma.patient.deleteMany();
  return result.count;
}

/**
 * Get all unencrypted patients for backup
 */
export async function getAllPatientsForBackup(): Promise<DecryptedPatient[]> {
  const patients = await prisma.patient.findMany({
    orderBy: { createdAt: 'desc' }
  });

  return patients.map(decryptPatient);
}

/**
 * Validate that user can update these fields
 */
function validateUpdatePermissions(data: Partial<PatientData>, role: string): void {
  if (role === 'ACCOUNTANT') {
    // Accountant can only update financial fields and package
    const allowedFields = ['package', 'cash', 'bank', 'balance'];
    const requestedFields = Object.keys(data);
    
    for (const field of requestedFields) {
      if (!allowedFields.includes(field)) {
        throw new Error(`Accountant cannot update field: ${field}`);
      }
    }
  } else if (role === 'SECRETARY') {
    // Secretary can only update non-financial fields
    const allowedFields = ['date', 'patientName', 'phone', 'address', 'package'];
    const requestedFields = Object.keys(data);
    
    for (const field of requestedFields) {
      if (!allowedFields.includes(field)) {
        throw new Error(`Secretary cannot update field: ${field}`);
      }
    }
  }
  // OWNER can update all fields
}
