// src/services/emailService.ts
import nodemailer from 'nodemailer';
import { getEncryption } from '../utils/encryption';
import { DecryptedPatient } from './patientService';

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

/**
 * Initialize email transporter
 */
export function initializeEmailService(): nodemailer.Transporter {
  if (transporter) return transporter;

  const config: EmailConfig = {
    host: process.env.SMTP_HOST || 'smtp.sendgrid.net',
    port: parseInt(process.env.SMTP_PORT || '587', 10),
    secure: false, // true for 465, false for 587
    auth: {
      user: process.env.SMTP_USER || 'apikey',
      pass: process.env.SMTP_PASS || ''
    }
  };

  transporter = nodemailer.createTransport(config);
  return transporter;
}

/**
 * Send backup email with encrypted attachment
 */
export async function sendBackupEmail(
  encryptedData: Buffer,
  fileName: string,
  subject: string = 'Monthly IVF Data Backup'
): Promise<boolean> {
  try {
    const transport = initializeEmailService();
    const backupEmail = process.env.BACKUP_EMAIL;

    if (!backupEmail) {
      console.error('BACKUP_EMAIL not configured');
      return false;
    }

    const mailOptions = {
      from: process.env.SMTP_USER || 'noreply@example.com',
      to: backupEmail,
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
    console.log('✓ Backup email sent:', info.messageId);
    return true;
  } catch (error) {
    console.error('Error sending backup email:', error);
    return false;
  }
}

/**
 * Generate encrypted backup file content
 */
export function generateEncryptedBackup(patients: DecryptedPatient[]): string {
  const encryption = getEncryption();
  
  // Create CSV content
  const headers = ['Date', 'Patient Name', 'Phone', 'Address', 'Package', 'Cash', 'Bank', 'Balance'];
  const rows = patients.map(patient => [
    patient.date || '',
    patient.patientName || '',
    patient.phone || '',
    patient.address || '',
    patient.package || '',
    patient.cash || '',
    patient.bank || '',
    patient.balance || ''
  ]);

  // Create CSV string with proper escaping
  const csvContent = [
    headers.map(h => `"${h}"`).join(','),
    ...rows.map(row => row.map(cell => `"${(cell || '').replace(/"/g, '""')}"`).join(','))
  ].join('\n');

  // Encrypt the CSV content
  const encryptedBackup = encryption.encrypt(csvContent);
  
  return encryptedBackup;
}
