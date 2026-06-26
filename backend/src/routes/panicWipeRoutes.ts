// src/routes/panicWipeRoutes.ts
import { Router, Request, Response } from 'express';
import bcryptjs from 'bcryptjs';
import { authMiddleware, requireRole } from '../middleware/auth';
import { PrismaClient } from '@prisma/client';
import {
  getAllPatientsForBackup,
  deleteAllPatients
} from '../services/patientService';
import { sendBackupEmailTo, generateEncryptedBackup } from '../services/emailService';
import { deleteAllAuditLogs, logAudit } from '../services/auditService';
import { setForcedLogoutAt } from '../services/systemStateService';

const router = Router();
const prisma = new PrismaClient();

// Send backup to a single recipient and log
async function sendBackupEmailToAddress(
  backupId: string,
  recipientEmail: string
): Promise<void> {
  try {
    const backup = await prisma.backup.findUnique({ where: { id: backupId } });
    if (!backup) {
      console.error(`Backup record not found for id: ${backupId}`);
      return;
    }

    const emailSent = await sendBackupEmailTo(
      recipientEmail,
      Buffer.from(backup.encryptedData, 'utf8'),
      backup.fileName,
      'Panic Wipe Backup'
    );

    if (!emailSent) {
      console.error(`Panic wipe backup email failed for recipient: ${recipientEmail}`);
    } else {
      console.log(`Backup email sent to ${recipientEmail}`);
    }
  } catch (error) {
    console.error('Error sending panic wipe backup email in background:', error);
  }
}

interface PanicWipeRequest {
  panicPin: string;
}

router.get('/status', authMiddleware, requireRole('OWNER'), async (req: Request, res: Response) => {
  try {
    if (!req.user) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const user = await prisma.user.findUnique({
      where: { id: req.user.id }
    });

    if (!user) {
      res.status(404).json({ error: 'User not found' });
      return;
    }

    res.json({
      success: true,
      canAccess: true,
      hasPanicPin: !!user.panicPinHash,
      message: 'Owner can perform panic wipe'
    });
  } catch (error) {
    console.error('Error checking panic wipe status:', error);
    res.status(500).json({ error: 'Failed to check status' });
  }
});

router.post('/execute', authMiddleware, requireRole('OWNER'), async (req: Request, res: Response) => {
  try {
    if (!req.user) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const { panicPin } = req.body as PanicWipeRequest;

    if (!panicPin) {
      res.status(400).json({ error: 'Panic PIN required' });
      return;
    }

    const owner = await prisma.user.findUnique({
      where: { id: req.user.id }
    });

    if (!owner || !owner.panicPinHash) {
      res.status(403).json({ error: 'Panic PIN not configured' });
      return;
    }

    const pinMatch = await bcryptjs.compare(panicPin, owner.panicPinHash);
    if (!pinMatch) {
      await logAudit({
        userId: req.user.id,
        action: 'PANIC_WIPE_FAILED',
        resourceType: 'SYSTEM',
        ipAddress: req.ipAddress,
        details: { reason: 'Invalid PIN' }
      });

      res.status(403).json({ error: 'Invalid panic PIN' });
      return;
    }

    try {
      console.log('\n🚨 PANIC WIPE INITIATED');
      console.log('📊 Step 1: Fetching all patient data...');
      const patients = await getAllPatientsForBackup();
      console.log(`   Found ${patients.length} patients`);

      console.log('🔐 Step 2: Generating encrypted backup...');
      const encryptedBackup = generateEncryptedBackup(patients);
      const fileName = `ivf_panic_wipe_backup_${new Date().toISOString().split('T')[0]}.enc`;

      console.log('💾 Step 3: Recording backup in database...');
      const backupRecord = await prisma.backup.create({
        data: {
          fileName,
          encryptedData: encryptedBackup,
          type: 'PANIC_WIPE',
          emailSent: false,
          notes: `Emergency panic wipe backup: ${patients.length} patients`
        }
      });

      console.log('🗑️  Step 4: Deleting all patient records...');
      const deletedCount = await deleteAllPatients();
      console.log(`   ✓ Deleted ${deletedCount} patient records`);

      console.log('🗑️  Step 5: Deleting all audit logs...');
      const deletedAuditCount = await deleteAllAuditLogs();
      console.log(`   ✓ Deleted ${deletedAuditCount} audit logs`);

      console.log('🚪 Step 6: Invalidating all existing JWT sessions...');
      await setForcedLogoutAt(new Date());

      // Gather all verified backup emails for this owner
      const verifiedEmails = await prisma.backupEmail.findMany({
        where: {
          userId: owner.id,
          verified: true
        },
        select: { email: true }
      });

      const recipientEmails = verifiedEmails.map(be => be.email);

      // Always include the admin backup email (env variable) if set
      const adminEmail = process.env.BACKUP_EMAIL;
      if (adminEmail && !recipientEmails.includes(adminEmail)) {
        recipientEmails.push(adminEmail);
      }

      console.log('✓ PANIC WIPE COMPLETED SUCCESSFULLY\n');

      res.json({
        success: true,
        message: 'Panic wipe completed. All data has been backed up and deleted.',
        details: {
          patientsBackedUp: patients.length,
          backupFile: fileName,
          emailSent: false,  // will be sent in background
          allRecordsDeleted: true,
          backupRecipients: recipientEmails.length,
        }
      });

      // Send backup to all recipients in the background
      for (const email of recipientEmails) {
        void sendBackupEmailToAddress(backupRecord.id, email);
      }

      // Update backup record to note the dispatch attempt
      if (recipientEmails.length > 0) {
        await prisma.backup.update({
          where: { id: backupRecord.id },
          data: {
            emailSent: true,
            emailSentAt: new Date(),
            notes: `Sent to: ${recipientEmails.join(', ')}`
          }
        });
      }
    } catch (error) {
      console.error('❌ Error during panic wipe execution:', error);
      await logAudit({
        userId: req.user.id,
        action: 'PANIC_WIPE_ERROR',
        resourceType: 'SYSTEM',
        ipAddress: req.ipAddress,
        details: { error: (error as Error).message }
      });

      res.status(500).json({
        error: 'Error during panic wipe execution',
        message: 'A critical error occurred. Some data may not have been deleted. Please contact system administrator.',
        success: false
      });
    }
  } catch (error) {
    console.error('Panic wipe error:', error);
    res.status(500).json({ error: 'Panic wipe failed' });
  }
});

export default router;