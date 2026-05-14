# IVF Patient Data Management System

A comprehensive, secure, full-stack application for managing IVF patient data with role-based access control, field-level encryption, and advanced security features including panic wipe functionality.

## Project Structure

```
IVF/
├── backend/                 # Node.js + Express + TypeScript API
│   ├── src/
│   │   ├── index.ts                 # Main application entry
│   │   ├── middleware/
│   │   │   └── auth.ts              # JWT authentication middleware
│   │   ├── routes/
│   │   │   ├── authRoutes.ts        # Authentication endpoints
│   │   │   ├── patientRoutes.ts     # Patient CRUD endpoints
│   │   │   ├── panicWipeRoutes.ts   # Panic wipe endpoint
│   │   │   └── auditRoutes.ts       # Audit logging endpoints
│   │   ├── services/
│   │   │   ├── patientService.ts    # Patient business logic
│   │   │   ├── auditService.ts      # Audit logging service
│   │   │   ├── emailService.ts      # Email backup service
│   │   │   └── scheduledJobsService.ts # Cron jobs
│   │   └── utils/
│   │       ├── encryption.ts        # AES-256-GCM encryption
│   │       └── jwt.ts               # JWT utilities
│   ├── prisma/
│   │   ├── schema.prisma            # Database schema
│   │   └── seed.ts                  # Database seeding
│   ├── package.json
│   ├── tsconfig.json
│   └── .env.example
└── flutter_app/             # Flutter mobile + web app
    ├── lib/
    │   ├── main.dart
    │   ├── models/
    │   │   ├── user.dart
    │   │   └── patient.dart
    │   ├── providers/
    │   │   ├── auth_provider.dart
    │   │   └── patient_provider.dart
    │   ├── services/
    │   │   ├── api_service.dart
    │   │   └── secure_storage_service.dart
    │   ├── screens/
    │   │   ├── login_screen.dart
    │   │   ├── patient_list_screen.dart
    │   │   ├── patient_detail_screen.dart
    │   │   ├── add_patient_screen.dart
    │   │   ├── panic_wipe_screen.dart
    │   │   └── activity_screen.dart
    │   └── widgets/
    └── pubspec.yaml
```

## Features Implemented

### Phase 1: Backend Foundation ✅
- ✅ Express API with TypeScript
- ✅ PostgreSQL database with Prisma ORM
- ✅ JWT authentication with 3 pre-seeded users (Owner, Accountant, Secretary)
- ✅ AES-256-GCM encryption for sensitive fields
- ✅ Patient CRUD with role-based field filtering
- ✅ Encryption/Decryption at rest
- ✅ Helmet.js security headers
- ✅ CORS middleware

### Phase 2: Backend Advanced Features ✅
- ✅ Panic wipe endpoint with email backup before deletion
- ✅ Monthly automated backups (cron job on 1st at 2:00 AM)
- ✅ Automatic data deletion for 6+ month old records (daily at 3:00 AM)
- ✅ Comprehensive audit logging (LOGIN, CREATE, UPDATE, DELETE, BACKUP, PANIC_WIPE)
- ✅ Email service integration (nodemailer + SendGrid/AWS SES)
- ✅ Immutable audit log with timestamps and user tracking
- ✅ Backup file encryption and secure storage

### Phase 3: Flutter Frontend ✅
- ✅ Login screen with demo credentials
- ✅ Patient list with search functionality
- ✅ Role-based column filtering (Secretary can't see cash, Accountant can't see phone)
- ✅ Patient detail view with role-restricted editing
- ✅ Add patient form with field permissions
- ✅ Panic wipe screen (Owner only) with 6-digit PIN entry
- ✅ Activity log view
- ✅ JWT token storage in secure storage
- ✅ Token refresh mechanism
- ✅ Network error handling
- ✅ Responsive design

## User Roles & Permissions

| Role | Access |
|------|--------|
| **Owner** (rakesh) | Full access to all fields. Can perform panic wipe. Can view audit logs. |
| **Accountant** | Financial fields only: Package, Cash, Bank, Balance + Patient Name (no Phone/Address) |
| **Secretary** | Non-financial fields: Date, Patient Name, Phone, Address, Package (no financial fields) |

## Encrypted Fields

The following fields are encrypted at rest using AES-256-GCM:
- `phone`
- `address`
- `cash`
- `bank`
- `balance`
- `date`
- `patientName`
- `package`

## Backend Setup

### Prerequisites
- Node.js 18+
- PostgreSQL 16+
- npm or yarn

### Installation

```bash
cd backend
npm install
```

### Environment Configuration

```bash
cp .env.example .env
```

Edit `.env` with your configuration:

```env
DATABASE_URL="postgresql://user:password@localhost:5432/ivf_db"
JWT_SECRET="your-super-secret-jwt-key"
ENCRYPTION_KEY="5a44b91551d2d83c976312b1c8ee5b5a04eca4b6061c5da664c8f28c64fa18db"
BACKUP_EMAIL="admin@example.com"
SMTP_HOST="smtp.sendgrid.net"
SMTP_PORT=587
SMTP_USER="apikey"
SMTP_PASS="SG.xxxxx..."
PANIC_PIN_HASH="$2b$10/..."  # bcrypt hash of your 6-digit PIN
PORT=3000
NODE_ENV="development"
```

### Database Setup

```bash
# Generate Prisma client
npm run prisma:generate

# Run migrations
npm run prisma:migrate

# Seed with demo users
npm run prisma:seed
```

### Running the Backend

```bash
# Development
npm run dev

# Production build
npm run build
npm start
```

The API will be available at `http://localhost:3000`

## Flutter App Setup

### Prerequisites
- Flutter 3.x
- Dart 3.x
- Android Studio / Xcode (for mobile builds)

### Installation

```bash
cd flutter_app
flutter pub get
```

### Configuration

Update API base URL in `lib/services/api_service.dart` if needed:

```dart
static const String _baseUrl = 'http://localhost:3000/api';
```

For mobile builds:
- Android: Update target SDK in `android/app/build.gradle`
- iOS: Update deployment target in `ios/Podfile`

### Running the App

```bash
# Web
flutter run -d chrome

# Android
flutter run -d emulator-5554

# iOS
flutter run -d iPhone
```

## API Endpoints

### Authentication
- `POST /api/auth/login` - Login with username/password
- `POST /api/auth/verify` - Verify token validity
- `POST /api/auth/refresh` - Refresh expired token

### Patients
- `GET /api/patients` - Get all patients (role-filtered)
- `GET /api/patients/:id` - Get specific patient
- `POST /api/patients` - Create new patient
- `PATCH /api/patients/:id` - Update patient
- `DELETE /api/patients/:id` - Delete patient (Owner only)

### Panic Wipe
- `GET /api/panic-wipe/status` - Check if owner can perform panic wipe
- `POST /api/panic-wipe/execute` - Execute panic wipe with PIN

### Audit
- `GET /api/audit/logs` - Get all audit logs (Owner only)
- `GET /api/audit/my-activity` - Get current user's activity

## Test Credentials

```
Owner:
  Username: rakesh
  Password: owner123
  Panic PIN: 123456

Accountant:
  Username: accountant
  Password: accountant123

Secretary:
  Username: secretary
  Password: secretary123
```

## Security Features

### Encryption
- **Algorithm**: AES-256-GCM
- **Key Length**: 32 bytes (256 bits)
- **IV**: 16 bytes randomly generated per encryption
- **Auth Tag**: 16 bytes for authentication
- **Delivery**: Base64 encoded for database storage

### Authentication
- JWT tokens with 7-day expiry
- Secure token storage in Flutter app (flutter_secure_storage)
- Token refresh mechanism
- Automatic logout on token expiration

### Panic Wipe Security
- Requires Owner role
- 6-digit PIN verification (bcrypt hashed)
- **Two-step process:**
  1. Create encrypted backup and email to configured address
  2. Only after successful email, delete all records
- Immutable audit log of wipe event
- No recovery option (by design)

### Data Protection
- HTTPS enforcement via Helmet.js
- CORS restricted by role/domain
- Rate limiting ready (implement via express-rate-limit)
- SQL injection protection via Prisma ORM
- XSS protection via Helmet.js

### Audit Logging
- Every login attempt
- All CRUD operations with user ID, IP, timestamp
- Backup operations
- Panic wipe events
- Immutable audit trail in database

## Scheduled Jobs

### Monthly Backup (1st of month, 2:00 AM)
- Exports all patient data
- Encrypts with AES-256-GCM
- Sends to configured email via SMTP
- Records backup metadata in database

### Auto-Delete (Daily, 3:00 AM)
- Finds records older than 6 months
- Permanently deletes via Prisma
- Logs action to audit trail

## Email Configuration

### SendGrid Example
```env
SMTP_HOST="smtp.sendgrid.net"
SMTP_PORT=587
SMTP_USER="apikey"
SMTP_PASS="SG.your_sendgrid_api_key"
```

### AWS SES Example
```env
SMTP_HOST="email-smtp.us-east-1.amazonaws.com"
SMTP_PORT=587
SMTP_USER="your_ses_username"
SMTP_PASS="your_ses_password"
```

## Deployment

### Backend (VPS/Docker)
```bash
# Build Docker image
docker build -t ivf-backend .

# Run container
docker run -p 3000:3000 --env-file .env ivf-backend
```

Or use PM2:
```bash
npm install -g pm2
npm run build
pm2 start dist/index.js --name "ivf-api"
```

### Frontend (Web/App Store)
```bash
# Web deployment
flutter build web --release

# Android APK
flutter build apk --release

# iOS App
flutter build ios --release
```

## Troubleshooting

### Database Connection Issues
- Verify PostgreSQL is running: `psql -U postgres`
- Check DATABASE_URL format
- Run `npm run prisma:migrate` to create tables

### Encryption Key Issues
- Key must be exactly 64 hex characters (32 bytes)
- Generate new key: `node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"`

### API Connection from Flutter
- For local development: Update API URL to your machine's IP
- Ensure backend is running: `curl http://localhost:3000/health`
- Check CORS headers in response

### Token Expiration
- Tokens expire after 7 days
- App automatically refreshes on requests
- Manual logout available in settings

## Performance Optimizations

- Database indexes on `createdAt` and `timestamp` for faster queries
- Encryption/decryption only on sensitive fields
- Caching via Provider state management
- Lazy loading of patient data
- Pagination ready for audit logs and patient list

## Future Enhancements

- 2FA for Owner account
- File upload for patient documents
- Advanced search and filtering
- Data export to CSV/PDF
- Mobile app notifications
- Dark mode
- Multi-language support
- Rate limiting and DDoS protection
- Redis caching layer
- GraphQL API alternative

## License

MIT

## Support

For issues or questions, please create an issue in the repository.
