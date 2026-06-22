-- AlterTable
ALTER TABLE "User" ADD COLUMN     "backupEmail" TEXT,
ADD COLUMN     "backupEmailVerified" BOOLEAN NOT NULL DEFAULT false;
