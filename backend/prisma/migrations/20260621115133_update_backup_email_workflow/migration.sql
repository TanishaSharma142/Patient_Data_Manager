-- AlterTable
ALTER TABLE "User" ADD COLUMN     "pendingBackupEmail" TEXT,
ADD COLUMN     "pendingVerificationCode" TEXT,
ADD COLUMN     "verificationCodeExpiry" TIMESTAMP(3);
