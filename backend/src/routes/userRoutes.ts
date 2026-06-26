import { Router, Request, Response } from 'express';
import { PrismaClient } from '@prisma/client';
import bcryptjs from 'bcryptjs';
import { authMiddleware, requireRole } from '../middleware/auth';
import { generateTemporaryPassword } from '../utils/password';
import { logAudit } from '../services/auditService';
import { sendVerificationCodeEmail } from '../services/emailService';

const router = Router();
const prisma = new PrismaClient();

interface CreateUserRequest {
  username: string;
  email?: string;
  role: 'OWNER' | 'ACCOUNTANT' | 'SECRETARY';
}

// ─── User CRUD (unchanged except removed backup email references) ──────────

router.get('/', authMiddleware, requireRole('OWNER'), async (req: Request, res: Response) => {
  try {
    const users = await prisma.user.findMany({
      select: {
        id: true,
        username: true,
        email: true,
        role: true,
        mustChangePassword: true,
        createdAt: true,
        updatedAt: true,
      }
    });
    res.json({ success: true, data: users });
  } catch (error) {
    console.error('Fetch users error:', error);
    res.status(500).json({ error: 'Failed to fetch users' });
  }
});

router.post('/', authMiddleware, requireRole('OWNER'), async (req: Request, res: Response) => {
  try {
    const { username, email, role } = req.body as CreateUserRequest;
    const normalizedEmail = email?.trim() || `${username}@example.com`;

    if (!username || !role) {
      res.status(400).json({ error: 'username and role are required' });
      return;
    }

    const normalizedRole = role.toUpperCase();
    if (!['OWNER', 'ACCOUNTANT', 'SECRETARY'].includes(normalizedRole)) {
      res.status(400).json({ error: 'Invalid role' });
      return;
    }

    const existing = await prisma.user.findFirst({
      where: {
        OR: [
          { username },
          { email: normalizedEmail }
        ]
      }
    });

    if (existing) {
      res.status(409).json({ error: 'Username or email already exists' });
      return;
    }

    const tempPassword = generateTemporaryPassword(8);
    const passwordHash = await bcryptjs.hash(tempPassword, 10);

    const user = await prisma.user.create({
      data: {
        username,
        email: normalizedEmail,
        role: normalizedRole as 'OWNER' | 'ACCOUNTANT' | 'SECRETARY',
        passwordHash,
        mustChangePassword: true,
      }
    });

    await logAudit({
      userId: req.user!.id,
      action: 'CREATE',
      resourceType: 'USER',
      resourceId: user.id,
      ipAddress: req.ip || req.socket.remoteAddress || 'unknown',
      details: { username: user.username, role: user.role }
    });

    res.status(201).json({
      success: true,
      data: {
        id: user.id,
        username: user.username,
        email: user.email,
        role: user.role,
        mustChangePassword: user.mustChangePassword,
      },
      tempPassword
    });
  } catch (error) {
    console.error('Create user error:', error);
    res.status(500).json({ error: 'Failed to create user' });
  }
});

router.post('/:id/reset-password', authMiddleware, requireRole('OWNER'), async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const user = await prisma.user.findUnique({ where: { id } });

    if (!user) {
      res.status(404).json({ error: 'User not found' });
      return;
    }

    const tempPassword = generateTemporaryPassword(8);
    const passwordHash = await bcryptjs.hash(tempPassword, 10);

    const updatedUser = await prisma.user.update({
      where: { id },
      data: {
        passwordHash,
        mustChangePassword: true,
      }
    });

    await logAudit({
      userId: req.user!.id,
      action: 'RESET_PASSWORD',
      resourceType: 'USER',
      resourceId: updatedUser.id,
      ipAddress: req.ip || req.socket.remoteAddress || 'unknown',
      details: { username: updatedUser.username }
    });

    res.json({
      success: true,
      data: {
        id: updatedUser.id,
        username: updatedUser.username,
        email: updatedUser.email,
        role: updatedUser.role,
        mustChangePassword: updatedUser.mustChangePassword,
      },
      tempPassword
    });
  } catch (error) {
    console.error('Reset password error:', error);
    res.status(500).json({ error: 'Failed to reset password' });
  }
});

router.delete('/:id', authMiddleware, requireRole('OWNER'), async (req: Request, res: Response) => {
  try {
    const { id } = req.params;

    const user = await prisma.user.findUnique({ where: { id } });
    if (!user) {
      res.status(404).json({ error: 'User not found' });
      return;
    }

    if (user.id === req.user!.id) {
      res.status(403).json({ error: 'Cannot delete your own account' });
      return;
    }

    if (user.role === 'OWNER') {
      res.status(403).json({ error: 'Cannot delete another owner account' });
      return;
    }

    await prisma.user.delete({ where: { id } });

    await logAudit({
      userId: req.user!.id,
      action: 'DELETE',
      resourceType: 'USER',
      resourceId: user.id,
      ipAddress: req.ip || req.socket.remoteAddress || 'unknown',
      details: { username: user.username, role: user.role }
    });

    res.json({ success: true, message: `User ${user.username} deleted` });
  } catch (error) {
    console.error('Delete user error:', error);
    res.status(500).json({ error: 'Failed to delete user' });
  }
});

// ─── Backup Email Management ────────────────────────────────────────

// Prevent adding the env admin email as a backup
function isEnvBackupEmail(email: string): boolean {
  const envEmail = process.env.BACKUP_EMAIL;
  if (!envEmail) return false;
  return email.toLowerCase() === envEmail.toLowerCase();
}

// GET /users/backup-emails - list all backup emails for the logged-in owner
router.get('/backup-emails', authMiddleware, requireRole('OWNER'), async (req: Request, res: Response) => {
  try {
    const backupEmails = await prisma.backupEmail.findMany({
      where: { userId: req.user!.id },
      orderBy: { createdAt: 'asc' }
    });
    res.json({ success: true, data: backupEmails });
  } catch (error) {
    console.error('Fetch backup emails error:', error);
    res.status(500).json({ error: 'Failed to fetch backup emails' });
  }
});

// POST /users/backup-email/send-code - send verification code to provided email
router.post('/backup-email/send-code', authMiddleware, requireRole('OWNER'), async (req: Request, res: Response) => {
  try {
    const { email } = req.body;

    if (!email || typeof email !== 'string') {
      res.status(400).json({ error: 'Email is required' });
      return;
    }

    // Basic email validation
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      res.status(400).json({ error: 'Invalid email format' });
      return;
    }

    // Prevent adding the env admin email
    if (isEnvBackupEmail(email)) {
      res.status(400).json({ error: 'This email cannot be added as a backup email.' });
      return;
    }

    const userId = req.user!.id;

    // Check if already exists
    const existing = await prisma.backupEmail.findUnique({
      where: {
        userId_email: { userId, email }
      }
    });

    if (existing && existing.verified) {
      res.status(409).json({ error: 'This email is already verified and added.' });
      return;
    }

    // Generate 6-digit code and expiration (10 minutes)
    const verificationCode = Math.floor(100000 + Math.random() * 900000).toString();
    const codeExpiresAt = new Date(Date.now() + 10 * 60 * 1000); // 10 min

    if (existing) {
      // Resend code for unverified entry
      await prisma.backupEmail.update({
        where: { id: existing.id },
        data: {
          verificationCode,
          codeExpiresAt,
        }
      });
    } else {
      // Create new unverified entry
      await prisma.backupEmail.create({
        data: {
          userId,
          email,
          verified: false,
          verificationCode,
          codeExpiresAt,
        }
      });
    }

    const emailSent = await sendVerificationCodeEmail(email, verificationCode);

    await logAudit({
      userId,
      action: 'UPDATE',
      resourceType: 'USER',
      resourceId: userId,
      ipAddress: req.ip || req.socket.remoteAddress || 'unknown',
      details: { action: 'SEND_BACKUP_EMAIL_VERIFICATION', email }
    });

    // In production never expose the code; in dev we can show it for convenience
    const showCode = process.env.NODE_ENV !== 'production' ? verificationCode : undefined;

    res.json({
      success: true,
      message: emailSent
        ? 'Verification code sent to your email.'
        : 'Failed to send verification email. Please try again.',
      emailSent,
      // Only include code if email failed or dev mode (useful for debugging)
      verificationCode: emailSent ? showCode : verificationCode,
    });
  } catch (error) {
    console.error('Send backup email verification error:', error);
    res.status(500).json({ error: 'Failed to send verification code' });
  }
});

// POST /users/backup-email/verify - verify the code for a specific email
router.post('/backup-email/verify', authMiddleware, requireRole('OWNER'), async (req: Request, res: Response) => {
  try {
    const { email, code } = req.body;

    if (!email || !code) {
      res.status(400).json({ error: 'Email and verification code are required.' });
      return;
    }

    const userId = req.user!.id;

    // Find the unverified entry for this user and email
    const entry = await prisma.backupEmail.findFirst({
      where: {
        userId,
        email,
        verified: false,
      }
    });

    if (!entry) {
      res.status(404).json({ error: 'No pending verification for this email.' });
      return;
    }

    // Check expiration
    if (!entry.codeExpiresAt || entry.codeExpiresAt < new Date()) {
      // Delete expired entry
      await prisma.backupEmail.delete({ where: { id: entry.id } });
      res.status(400).json({ error: 'Verification code expired. Please request a new one.' });
      return;
    }

    // Validate code
    if (entry.verificationCode !== code) {
      res.status(400).json({ error: 'Invalid verification code.' });
      return;
    }

    // Mark as verified and clear code fields
    const updatedEntry = await prisma.backupEmail.update({
      where: { id: entry.id },
      data: {
        verified: true,
        verificationCode: null,
        codeExpiresAt: null,
      }
    });

    await logAudit({
      userId,
      action: 'UPDATE',
      resourceType: 'USER',
      resourceId: userId,
      ipAddress: req.ip || req.socket.remoteAddress || 'unknown',
      details: { action: 'VERIFY_BACKUP_EMAIL', email: updatedEntry.email }
    });

    res.json({
      success: true,
      message: 'Backup email verified successfully.',
      data: {
        id: updatedEntry.id,
        email: updatedEntry.email,
        verified: updatedEntry.verified,
      }
    });
  } catch (error) {
    console.error('Verify backup email error:', error);
    res.status(500).json({ error: 'Failed to verify backup email' });
  }
});

// DELETE /users/backup-emails/:id - remove a backup email
router.delete('/backup-emails/:id', authMiddleware, requireRole('OWNER'), async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const entry = await prisma.backupEmail.findUnique({ where: { id } });

    if (!entry) {
      res.status(404).json({ error: 'Backup email not found' });
      return;
    }

    if (entry.userId !== req.user!.id) {
      res.status(403).json({ error: 'Unauthorized' });
      return;
    }

    await prisma.backupEmail.delete({ where: { id } });

    await logAudit({
      userId: req.user!.id,
      action: 'DELETE',
      resourceType: 'USER',
      resourceId: req.user!.id,
      ipAddress: req.ip || req.socket.remoteAddress || 'unknown',
      details: { action: 'REMOVE_BACKUP_EMAIL', email: entry.email }
    });

    res.json({ success: true, message: 'Backup email removed.' });
  } catch (error) {
    console.error('Delete backup email error:', error);
    res.status(500).json({ error: 'Failed to remove backup email' });
  }
});

export default router;