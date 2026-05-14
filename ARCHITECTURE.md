# IVF Patient Management System - Architecture Document

## System Design Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         End Users                                 │
│  (Owner / Accountant / Secretary)                                │
└──────────────────────┬──────────────────────────────────────────┘
                       │
        ┌──────────────┼──────────────┐
        │              │              │
    ┌─────────┐  ┌─────────┐  ┌──────────┐
    │ Mobile  │  │ Mobile  │  │   Web    │
    │ Android │  │  iOS    │  │ Browser  │
    └────┬────┘  └────┬────┘  └────┬─────┘
         │            │            │
         └────────────┼────────────┘
                      │
         ┌────────────▼────────────┐
         │  Flutter Application    │
         │  (Single Codebase)      │
         │  ├─ Login Screen        │
         │  ├─ Patient List        │
         │  ├─ Patient Detail      │
         │  ├─ Add Patient Form    │
         │  ├─ Panic Wipe (Owner)  │
         │  └─ Activity Log        │
         └────────────┬────────────┘
                      │ HTTPS/REST
         ┌────────────▼────────────┐
         │   Express.js Backend    │
         │   (Node.js + TypeScript)│
         ├─ Auth Routes            │
         ├─ Patient CRUD Routes    │
         ├─ Panic Wipe Routes      │
         └─ Audit Routes           │
                      │
         ┌────────────┼────────────┐
         │            │            │
    ┌────▼───┐  ┌─────▼──┐  ┌─────▼──┐
    │  Auth  │  │Patient │  │ Panic  │
    │Service │  │Service │  │ Wipe   │
    └────┬───┘  └─────┬──┘  │Service │
         │            │     └─────┬──┘
    ┌────▼────────────▼───────────┴────┐
    │        Service Layer             │
    ├─ JWT Token Generation            │
    ├─ Encryption/Decryption (AES-256) │
    ├─ Audit Logging                   │
    ├─ Email Service                   │
    └─ Scheduled Jobs (node-cron)      │
                      │
    ┌─────────────────▼──────────────┐
    │    PostgreSQL Database         │
    ├─ Users (encrypted passwords)   │
    ├─ Patients (encrypted fields)   │
    ├─ AuditLogs (immutable)        │
    └─ Backups (encrypted data)     │
```

## Component Architecture

### Frontend Layer (Flutter)

```
Flutter Application
│
├── Screens (UI Pages)
│   ├── LoginScreen
│   │   └── Authentication form, demo credentials
│   ├── PatientListScreen
│   │   ├── Patient list view
│   │   ├── Search functionality
│   │   └── Role-based column filtering
│   ├── PatientDetailScreen
│   │   ├── View patient details
│   │   ├── Edit form (role-restricted fields)
│   │   └── Delete button (Owner only)
│   ├── AddPatientScreen
│   │   └── New patient form
│   ├── PanicWipeScreen
│   │   ├── 6-digit PIN entry pad
│   │   └── Confirmation dialogs
│   └── ActivityScreen
│       └── Audit log viewer
│
├── Providers (State Management)
│   ├── AuthProvider
│   │   ├── User authentication
│   │   ├── Token management
│   │   └── Role-based access
│   └── PatientProvider
│       ├── Patient list state
│       ├── CRUD operations
│       └── Search/filter
│
├── Services (HTTP & Storage)
│   ├── ApiService
│   │   ├── REST API calls
│   │   ├── Token injection
│   │   └── Error handling
│   └── SecureStorageService
│       ├── JWT token storage
│       ├── Secure read/write
│       └── Token refresh
│
└── Models (Data Classes)
    ├── User
    └── Patient
```

### Backend Layer (Node.js/Express)

```
Express Application
│
├── Routes (HTTP Endpoints)
│   ├── POST /auth/login
│   ├── POST /auth/verify
│   ├── POST /auth/refresh
│   ├── GET/POST/PATCH/DELETE /patients
│   ├── GET /panic-wipe/status
│   ├── POST /panic-wipe/execute
│   ├── GET /audit/logs
│   └── GET /audit/my-activity
│
├── Middleware (Request Processing)
│   ├── authMiddleware (JWT verification)
│   ├── requireRole (role-based access)
│   ├── CORS handler
│   ├── Helmet (security headers)
│   └── Body parser
│
├── Services (Business Logic)
│   ├── PatientService
│   │   ├── createPatient()
│   │   ├── getPatientById()
│   │   ├── getAllPatients()
│   │   ├── updatePatient()
│   │   ├── deletePatient()
│   │   ├── deleteAllPatients()
│   │   ├── getAllPatientsForBackup()
│   │   └── Encryption/Decryption
│   │
│   ├── AuditService
│   │   ├── logAudit()
│   │   ├── getAuditLogs()
│   │   ├── getAuditLogsByUser()
│   │   └── getAuditLogsByAction()
│   │
│   ├── EmailService
│   │   ├── initializeEmailService()
│   │   ├── sendBackupEmail()
│   │   └── generateEncryptedBackup()
│   │
│   └── ScheduledJobsService
│       ├── scheduleMonthlyBackup()
│       ├── scheduleAutoDataDeletion()
│       └── initializeScheduledJobs()
│
├── Utils (Helper Functions)
│   ├── Encryption (AES-256-GCM)
│   │   ├── encrypt()
│   │   └── decrypt()
│   └── JWT
│       ├── signToken()
│       ├── verifyToken()
│       └── decodeToken()
│
└── Database Connection (Prisma ORM)
    └── PostgreSQL
```

## Data Security Architecture

### Encryption Strategy

```
Sensitive Data Handling:
┌──────────────────────────────────────┐
│  Incoming Data (from API request)    │
└──────────┬───────────────────────────┘
           │
           ▼
┌──────────────────────────────────────┐
│  Field Validation (schema)           │
└──────────┬───────────────────────────┘
           │
           ▼
┌──────────────────────────────────────┐
│  Role-based Field Access Check      │
└──────────┬───────────────────────────┘
           │
           ▼
┌──────────────────────────────────────┐
│  Encrypt Sensitive Fields:           │
│  - Date                              │
│  - PatientName                       │
│  - Phone                             │
│  - Address                           │
│  - Package                           │
│  - Cash                              │
│  - Bank                              │
│  - Balance                           │
└──────────┬───────────────────────────┘
           │
           ▼
┌──────────────────────────────────────┐
│  AES-256-GCM Encryption:             │
│  1. Generate 16-byte random IV       │
│  2. Encrypt with 32-byte key         │
│  3. Get 16-byte auth tag             │
│  4. Combine: IV + AuthTag + Data     │
│  5. Base64 encode for storage        │
└──────────┬───────────────────────────┘
           │
           ▼
┌──────────────────────────────────────┐
│  Store in Database                   │
│  (All fields encrypted as strings)   │
└──────────────────────────────────────┘
```

### Decryption & Role Filtering

```
Database Retrieval:
┌──────────────────────────────────┐
│  Query encrypted data from DB    │
└──────────┬──────────────────────┘
           │
           ▼
┌──────────────────────────────────┐
│  For each encrypted field:       │
│  1. Base64 decode                │
│  2. Extract IV (16 bytes)        │
│  3. Extract AuthTag (16 bytes)   │
│  4. Decrypt remaining data       │
│  5. Return plaintext             │
└──────────┬──────────────────────┘
           │
           ▼
┌──────────────────────────────────┐
│  Role-based Field Filtering      │
│  Owner: All fields               │
│  Accountant: Financials only     │
│  Secretary: Non-financials only  │
└──────────┬──────────────────────┘
           │
           ▼
┌──────────────────────────────────┐
│  Return filtered data to client  │
└──────────────────────────────────┘
```

## Authentication Flow

```
User Login:
┌────────────┐
│   Client   │ POST /auth/login {username, password}
└─────┬──────┘
      │
      ▼
┌──────────────────────┐
│ Find user in DB      │
│ by username          │
└──────┬───────────────┘
       │
       ▼
┌──────────────────────┐
│ Compare passwords:   │
│ bcryptjs.compare()   │
└──────┬───────────────┘
       │
       ├─ Match
       │  └──▶ Generate JWT token
       │       { id, username, role, email }
       │       Expiry: 7 days
       │       └──▶ Return token + user
       │
       └─ No Match
          └──▶ Return 401 error

Token Usage:
┌──────────────────────┐
│  Client stores JWT   │
│  in secure storage   │
└──────┬───────────────┘
       │
       ▼
┌──────────────────────┐
│  For each API call:  │
│  Include header:     │
│  Authorization:      │
│  Bearer <token>      │
└──────┬───────────────┘
       │
       ▼
┌──────────────────────┐
│  Backend middleware  │
│  Verify JWT token    │
│  Extract user info   │
└──────┬───────────────┘
       │
       ├─ Valid
       │  └──▶ Proceed to route
       │
       └─ Invalid/Expired
          └──▶ Return 401/refresh
```

## Panic Wipe Process

```
Owner Initiates Panic Wipe:
┌──────────────────────────────┐
│ 1. Navigate to Panic Wipe     │
│    screen (Flutter)          │
└──────────┬───────────────────┘
           │
           ▼
┌──────────────────────────────┐
│ 2. Enter 6-digit PIN         │
└──────────┬───────────────────┘
           │
           ▼
┌──────────────────────────────┐
│ 3. Show confirmation dialog  │
└──────────┬───────────────────┘
           │
           ▼
┌──────────────────────────────┐
│ 4. POST /panic-wipe/execute  │
│    {panicPin}                │
└──────────┬───────────────────┘
           │
           ▼
┌──────────────────────────────┐
│ 5. Backend:                  │
│    a) Verify Owner role      │
│    b) Verify PIN (bcrypt)    │
└──────────┬───────────────────┘
           │
           ├─ PIN Invalid
           │  └──▶ Log failed attempt
           │       Return 403 error
           │
           └─ PIN Valid
              │
              ▼
       ┌──────────────────────────────┐
       │ 6. Fetch ALL patient data    │
       │    (decrypt all records)     │
       └──────────┬───────────────────┘
                  │
                  ▼
       ┌──────────────────────────────┐
       │ 7. Generate encrypted backup:│
       │    a) Create CSV content     │
       │    b) Encrypt with AES-256   │
       │    c) Base64 encode          │
       └──────────┬───────────────────┘
                  │
                  ▼
       ┌──────────────────────────────┐
       │ 8. Send backup email         │
       │    Via SMTP/SendGrid          │
       │    Subject: EMERGENCY...      │
       └──────────┬───────────────────┘
                  │
                  ├─ Email Failed
                  │  └──▶ Log error
                  │       ABORT (no deletion)
                  │       Return 500
                  │
                  └─ Email Success
                     │
                     ▼
            ┌──────────────────────────────┐
            │ 9. Store backup record in DB │
            │    (Backup table)            │
            └──────────┬───────────────────┘
                       │
                       ▼
            ┌──────────────────────────────┐
            │ 10. DELETE ALL PATIENTS      │
            │     Prisma deleteMany()      │
            └──────────┬───────────────────┘
                       │
                       ▼
            ┌──────────────────────────────┐
            │ 11. Log PANIC_WIPE event:    │
            │     - User ID                │
            │     - IP Address             │
            │     - Timestamp              │
            │     - Record count           │
            └──────────┬───────────────────┘
                       │
                       ▼
            ┌──────────────────────────────┐
            │ 12. Return success response  │
            └─────────────────────────────┘
```

## Database Schema

```sql
-- Users table
CREATE TABLE "User" (
  id UUID PRIMARY KEY DEFAULT cuid(),
  username VARCHAR(255) UNIQUE NOT NULL,
  email VARCHAR(255) UNIQUE NOT NULL,
  passwordHash VARCHAR(255) NOT NULL,
  role ENUM('OWNER', 'ACCOUNTANT', 'SECRETARY') NOT NULL,
  panicPinHash VARCHAR(255),
  createdAt TIMESTAMP DEFAULT now(),
  updatedAt TIMESTAMP DEFAULT now()
);

-- Patients table (all fields encrypted)
CREATE TABLE "Patient" (
  id UUID PRIMARY KEY DEFAULT cuid(),
  dateEncrypted TEXT NOT NULL,
  patientNameEncrypted TEXT NOT NULL,
  phoneEncrypted TEXT NOT NULL,
  addressEncrypted TEXT NOT NULL,
  packageEncrypted TEXT NOT NULL,
  cashEncrypted TEXT NOT NULL,
  bankEncrypted TEXT NOT NULL,
  balanceEncrypted TEXT NOT NULL,
  createdAt TIMESTAMP DEFAULT now(),
  updatedAt TIMESTAMP DEFAULT now(),
  INDEX idx_createdAt (createdAt)
);

-- Audit logs table (immutable)
CREATE TABLE "AuditLog" (
  id UUID PRIMARY KEY DEFAULT cuid(),
  userId UUID NOT NULL,
  action VARCHAR(50) NOT NULL,
  resourceType VARCHAR(50),
  resourceId UUID,
  ipAddress VARCHAR(45),
  details JSON,
  timestamp TIMESTAMP DEFAULT now(),
  FOREIGN KEY (userId) REFERENCES "User"(id),
  INDEX idx_userId (userId),
  INDEX idx_timestamp (timestamp),
  INDEX idx_action (action)
);

-- Backups table
CREATE TABLE "Backup" (
  id UUID PRIMARY KEY DEFAULT cuid(),
  fileName VARCHAR(255) NOT NULL,
  encryptedData TEXT NOT NULL,
  type ENUM('MONTHLY', 'PANIC_WIPE') NOT NULL,
  createdAt TIMESTAMP DEFAULT now(),
  emailSent BOOLEAN DEFAULT false,
  emailSentAt TIMESTAMP,
  notes TEXT,
  INDEX idx_type (type),
  INDEX idx_createdAt (createdAt)
);
```

## State Management Flow (Flutter)

```
User Interaction (Tap Button)
│
▼
Screen Widget
│
├─ Calls Provider method
│ (e.g., PatientProvider.loadPatients())
│
▼
ChangeNotifier (Provider)
│
├─ Set isLoading = true
├─ Notify listeners (UI rebuilds)
│
▼
├─ Call ApiService method
│ (HTTP request to backend)
│
▼
├─ Receive response
│
├─ Update internal state
│ (List<Patient> patients = [...])
│
├─ Set isLoading = false
├─ Clear error or set error
├─ Notify listeners (UI rebuilds)
│
▼
UI Rebuilds with new data
```

## Error Handling Strategy

```
Frontend Error Handling:
─────────────────────────
1. Network Error
   └─ Show SnackBar with message
      Offer retry button

2. 401 Unauthorized
   └─ Clear local token
      Redirect to login
      Show "Session expired" message

3. 403 Forbidden
   └─ Show SnackBar "Insufficient permissions"
      Log action for debugging

4. 422 Validation Error
   └─ Show form errors
      Highlight invalid fields

5. 500 Server Error
   └─ Show SnackBar with error message
      Log error for debugging
      Offer retry option

Backend Error Handling:
──────────────────────
1. Authentication Errors
   └─ Return 401 with clear message

2. Authorization Errors
   └─ Return 403 with role information

3. Validation Errors
   └─ Return 400 with field validation details

4. Resource Not Found
   └─ Return 404 with resource type

5. Encryption/Decryption Errors
   └─ Log securely (don't expose key)
      Return 500 with generic message

6. Database Errors
   └─ Log with full context
      Return 500 with generic message
```

## Security Layers

```
Layer 1: Transport Security
├─ HTTPS/TLS only (enforce in production)
├─ Certificate pinning (optional)
└─ HSTS headers

Layer 2: Application Security
├─ JWT token validation on every request
├─ Role-based access control (RBAC)
├─ Helmet.js security headers
│  ├─ Content-Security-Policy
│  ├─ X-Frame-Options
│  ├─ X-Content-Type-Options
│  └─ Strict-Transport-Security
└─ CORS configuration

Layer 3: Data Security
├─ AES-256-GCM encryption at rest
├─ Password hashing with bcryptjs
├─ Panic PIN hashing with bcryptjs
└─ Encrypted backup files

Layer 4: Access Control
├─ Field-level filtering (role-based)
├─ API endpoint protection
├─ Operation auditing
└─ Immutable audit logs

Layer 5: Infrastructure Security
├─ Environment variables (no hardcoding)
├─ Secrets management
├─ Database access control
├─ IP whitelisting (optional)
└─ Rate limiting (ready to implement)
```

## Performance Optimization

```
Database Query Optimization:
├─ Indexes on frequently queried fields
│  ├─ Patient.createdAt
│  ├─ AuditLog.userId
│  ├─ AuditLog.timestamp
│  └─ Backup.type
├─ Pagination support (limit/offset)
└─ Query result limiting

Caching Strategy:
├─ Flutter Provider caching (in-memory)
├─ JWT token caching (secure storage)
├─ Passenger list pagination
└─ Redis ready (future enhancement)

API Optimization:
├─ Minimal data transfer
├─ Field selection (only needed fields)
├─ Batch operations support
└─ Gzip compression

Encryption Optimization:
├─ Lazy decryption (only on request)
├─ Batch encryption for backups
└─ Async encryption/decryption
```

---

This architecture ensures **security**, **scalability**, and **maintainability** for the IVF patient data management system.
