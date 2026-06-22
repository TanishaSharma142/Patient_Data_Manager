/*
  Warnings:

  - You are about to drop the column `pendingBackupEmail` on the `User` table. All the data in the column will be lost.
  - You are about to drop the column `pendingVerificationCode` on the `User` table. All the data in the column will be lost.
  - You are about to drop the column `verificationCodeExpiry` on the `User` table. All the data in the column will be lost.

*/
-- AlterTable
ALTER TABLE "User" DROP COLUMN "pendingBackupEmail",
DROP COLUMN "pendingVerificationCode",
DROP COLUMN "verificationCodeExpiry";
