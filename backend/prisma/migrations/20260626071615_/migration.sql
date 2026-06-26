/*
  Warnings:

  - You are about to drop the column `backupEmail` on the `User` table. All the data in the column will be lost.
  - You are about to drop the column `backupEmailVerified` on the `User` table. All the data in the column will be lost.

*/
-- AlterTable
ALTER TABLE "User" DROP COLUMN "backupEmail",
DROP COLUMN "backupEmailVerified";

-- CreateTable
CREATE TABLE "BackupEmail" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "verified" BOOLEAN NOT NULL DEFAULT false,
    "verificationCode" TEXT,
    "codeExpiresAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "BackupEmail_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "BackupEmail_userId_idx" ON "BackupEmail"("userId");

-- CreateIndex
CREATE UNIQUE INDEX "BackupEmail_userId_email_key" ON "BackupEmail"("userId", "email");

-- AddForeignKey
ALTER TABLE "BackupEmail" ADD CONSTRAINT "BackupEmail_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
