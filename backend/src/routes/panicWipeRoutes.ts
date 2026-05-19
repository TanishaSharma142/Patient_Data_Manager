// src/routes/panicWipeRoutes.ts
import { Router, Request, Response } from 'express';
import bcryptjs from 'bcryptjs';
import { authMiddleware, requireRole } from '../middleware/auth';
import { PrismaClient } from '@prisma/client';
import {
  getAllPatientsForBackup,
  deleteAllPatients
} from '../services/patientService';
import { sendBackupEmail, generateEncryptedBackup } from '../services/emailService';
import { deleteAllAuditLogs, logAudit } from '../services/auditService';

const router = Router();
const prisma = new PrismaClient();

interface PanicWipeRequest {
  panicPin: string;
}

/**
 * GET /api/panic-wipe/status
 * Check if user can access panic wipe (OWNER only)
 */
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

/**
 * POST /api/panic-wipe/execute
 * Execute panic wipe: backup all data and delete everything
 * Requires valid panic PIN
 */
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

    // Get owner user
    const owner = await prisma.user.findUnique({
      where: { id: req.user.id }
    });

    if (!owner || !owner.panicPinHash) {
      res.status(403).json({ error: 'Panic PIN not configured' });
      return;
    }

    // Verify panic PIN
    const pinMatch = await bcryptjs.compare(panicPin, owner.panicPinHash);
    if (!pinMatch) {
      // Log failed attempt
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
      // Step 1: Get all patient data
      console.log('\n🚨 PANIC WIPE INITIATED');
      console.log('📊 Step 1: Fetching all patient data...');
      const patients = await getAllPatientsForBackup();
      console.log(`   Found ${patients.length} patients`);

      // Step 2: Generate encrypted backup
      console.log('🔐 Step 2: Generating encrypted backup...');
      const encryptedBackup = generateEncryptedBackup(patients);
      const fileName = `ivf_panic_wipe_backup_${new Date().toISOString().split('T')[0]}.enc`;
      const backupBuffer = Buffer.from(encryptedBackup, 'utf8');

      // Step 3: Send backup email
      console.log('📧 Step 3: Sending backup to email...');
      const emailSent = await sendBackupEmail(
        backupBuffer,
        fileName,
        'Something is spam'
      );

      if (!emailSent) {
        console.error('❌ Email sending failed - ABORTING panic wipe');
        res.status(500).json({
          error: 'Failed to send backup email. Panic wipe aborted. No data was deleted.',
          success: false
        });
        return;
      }

      console.log('   ✓ Backup email sent successfully');

      // Step 4: Store backup record
      console.log('💾 Step 4: Recording backup in database...');
      await prisma.backup.create({
        data: {
          fileName: fileName,
          encryptedData: encryptedBackup,
          type: 'PANIC_WIPE',
          emailSent: true,
          emailSentAt: new Date(),
          notes: `Emergency panic wipe backup: ${patients.length} patients`
        }
      });

      // Step 5: Delete all patient records
      console.log('🗑️  Step 5: Deleting all patient records...');
      const deletedCount = await deleteAllPatients();
      console.log(`   ✓ Deleted ${deletedCount} patient records`);

      // Step 6: Log panic wipe event (immutable audit log)
      console.log('📝 Step 6: Logging panic wipe event...');
      await logAudit({
        userId: req.user.id,
        action: 'PANIC_WIPE',
        resourceType: 'SYSTEM',
        ipAddress: req.ipAddress,
        details: {
          patientCount: patients.length,
          backupFileName: fileName,
          emailSent: true,
          timestamp: new Date().toISOString()
        }
      });

      // Step 7: Delete all audit logs
      console.log('🗑️  Step 7: Deleting all audit logs...');
      const deletedAuditCount = await deleteAllAuditLogs();
      console.log(`   ✓ Deleted ${deletedAuditCount} audit logs`);

      console.log('✓ PANIC WIPE COMPLETED SUCCESSFULLY\n');

      res.json({
        success: true,
        message: 'Panic wipe completed. All data has been backed up and deleted.',
        details: {
          patientsBackedUp: patients.length,
          backupFile: fileName,
          emailSent: true,
          allRecordsDeleted: true
        }
      });
    } catch (error) {
      console.error('❌ Error during panic wipe execution:', error);
      
      // Log the error
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
