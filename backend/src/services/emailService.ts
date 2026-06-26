// src/services/emailService.ts
import nodemailer from 'nodemailer';
import { PrismaClient } from '@prisma/client';
import { getEncryption } from '../utils/encryption';
import { DecryptedPatient } from './patientService';

const prisma = new PrismaClient();

interface EmailConfig {
  host: string;
  port: number;
  secure: boolean;
  auth: {
    user: string;
    pass: string;
  };
}

let transporter: nodemailer.Transporter | null = null;

export function initializeEmailService(): nodemailer.Transporter {
  if (transporter) return transporter;

  const config: EmailConfig = {
    host: process.env.SMTP_HOST || 'smtp.sendgrid.net',
    port: parseInt(process.env.SMTP_PORT || '587', 10),
    secure: false,
    auth: {
      user: process.env.SMTP_USER || 'apikey',
      pass: process.env.SMTP_PASS || ''
    }
  };

  transporter = nodemailer.createTransport(config);
  return transporter;
}

/**
 * Send backup email to a specific recipient
 */
export async function sendBackupEmailTo(
  toEmail: string,
  encryptedData: Buffer,
  fileName: string,
  subject: string = 'Monthly IVF Data Backup'
): Promise<boolean> {
  try {
    const transport = initializeEmailService();

    const mailOptions = {
      from: process.env.SMTP_USER || 'noreply@example.com',
      to: toEmail,
      subject: subject,
      text: 'Attached is your encrypted IVF patient data backup. Store this file safely. Only the system owner can decrypt it using the encryption key.',
      html: `
        <h2>${subject}</h2>
        <p>Attached is your encrypted IVF patient data backup.</p>
        <p><strong>Important:</strong> Store this file safely. Only the system owner can decrypt it using the encryption key.</p>
        <p>Backup generated at: ${new Date().toISOString()}</p>
      `,
      attachments: [
        {
          filename: fileName,
          content: encryptedData,
          contentType: 'application/octet-stream'
        }
      ]
    };

    const info = await transport.sendMail(mailOptions);
    console.log(`✓ Backup email sent to ${toEmail}: ${info.messageId}`);
    return true;
  } catch (error) {
    console.error(`Error sending backup email to ${toEmail}:`, error);
    return false;
  }
}

/**
 * Original sendBackupEmail – kept for backward compatibility,
 * sends only to the environment‑configured BACKUP_EMAIL.
 */
export async function sendBackupEmail(
  encryptedData: Buffer,
  fileName: string,
  subject: string = 'Monthly IVF Data Backup'
): Promise<boolean> {
  const backupEmail = process.env.BACKUP_EMAIL;
  if (!backupEmail) {
    console.error('BACKUP_EMAIL not configured');
    return false;
  }
  return sendBackupEmailTo(backupEmail, encryptedData, fileName, subject);
}

/**
 * Send verification code to a single email.
 */
export async function sendVerificationCodeEmail(to: string, verificationCode: string): Promise<boolean> {
  try {
    const transport = initializeEmailService();

    const mailOptions = {
      from: process.env.SMTP_USER || 'noreply@example.com',
      to,
      subject: 'Your verification code',
      text: `Your backup email verification code is: ${verificationCode}`,
      html: `
        <p>Your backup email verification code is:</p>
        <p><strong>${verificationCode}</strong></p>
        <p>Enter this code in the app to verify your backup email.</p>
      `
    };

    const info = await transport.sendMail(mailOptions);
    console.log('✓ Verification email sent to', to, 'messageId:', info.messageId);
    return true;
  } catch (error) {
    console.error('Error sending verification email:', error);
    return false;
  }
}

/**
 * Generate encrypted backup CSV content.
 */
export function generateEncryptedBackup(patients: DecryptedPatient[]): string {
  const encryption = getEncryption();
  
  const headers = [
    'ID',
    'Date',
    'Patient Name',
    'Country Code',
    'Phone',
    'Address',
    'Package',
    'Cash',
    'Bank',
    'Balance',
    'Cash Entries'
  ];

  const rows = patients.map(patient => [
    patient.id,
    patient.date || '',
    patient.patientName || '',
    patient.countryCode || '',
    patient.phone || '',
    patient.address || '',
    patient.package || '',
    patient.cash || '',
    patient.bank || '',
    patient.balance || '',
    JSON.stringify(patient.cashEntries ?? [])
  ]);

  const csvContent = [
    headers.map(h => `"${h}"`).join(','),
    ...rows.map(row => row.map(cell => `"${(cell || '').replace(/"/g, '""')}"`).join(','))
  ].join('\n');

  const encryptedBackup = encryption.encrypt(csvContent);
  return encryptedBackup;
}

/**
 * Retry failed backups – now sends to **all** verified backup emails
 * plus the environment admin email, instead of only the admin email.
 */
export async function retryFailedBackups(): Promise<{
  total: number;
  succeeded: number;
  failed: number;
  failures: Array<{ id: string; fileName: string; error: string }>;
}> {
  const failedBackups = await prisma.backup.findMany({
    where: { emailSent: false }
  });

  const result = {
    total: failedBackups.length,
    succeeded: 0,
    failed: 0,
    failures: [] as Array<{ id: string; fileName: string; error: string }>
  };

  // Gather all unique recipient emails across all owners
  // (this is a simplified approach – for each backup we could store intended recipients,
  // but here we resend to all currently verified backup emails + admin email).
  const verifiedBackupEmails = await prisma.backupEmail.findMany({
    where: { verified: true },
    select: { email: true }
  });
  const uniqueRecipients = new Set(verifiedBackupEmails.map(be => be.email));

  const adminEmail = process.env.BACKUP_EMAIL;
  if (adminEmail) {
    uniqueRecipients.add(adminEmail);
  }

  const recipients = Array.from(uniqueRecipients);
  if (recipients.length === 0) {
    console.warn('No backup email recipients configured – retry aborted.');
    return result;
  }

  for (const backup of failedBackups) {
    let allSent = true;
    for (const email of recipients) {
      try {
        const emailSent = await sendBackupEmailTo(
          email,
          Buffer.from(backup.encryptedData, 'utf8'),
          backup.fileName,
          'Backup Retry'
        );
        if (!emailSent) {
          allSent = false;
          console.error(`Retry failed for backup ${backup.id} to ${email}`);
        }
      } catch (error) {
        allSent = false;
        result.failures.push({
          id: backup.id,
          fileName: backup.fileName,
          error: `Failed to send to ${email}: ${(error as Error).message}`
        });
      }
    }

    if (allSent) {
      await prisma.backup.update({
        where: { id: backup.id },
        data: {
          emailSent: true,
          emailSentAt: new Date()
        }
      });
      result.succeeded += 1;
    } else {
      result.failed += 1;
      // If at least one recipient failed, we keep emailSent = false so it will be retried later.
    }
  }

  return result;
}