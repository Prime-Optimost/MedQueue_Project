# MedQueue Backend API Documentation

**Base URL:** `http://localhost:8000/api/v1/`  
**API Version:** v1  
**Last Updated:** May 3, 2026

---

## Table of Contents

1. [Authentication & JWT](#authentication--jwt)
2. [Response Format](#response-format)
3. [Error Handling](#error-handling)
4. [API Endpoints](#api-endpoints)
   - [Registration](#registration)
   - [OTP (One-Time Password)](#otp-one-time-password)
   - [Login / Logout](#login--logout)
   - [Password Reset](#password-reset)
   - [Profile Management](#profile-management)
   - [Admin User Management](#admin-user-management)
5. [Data Models](#data-models)
6. [Rate Limiting & Throttling](#rate-limiting--throttling)
7. [Error Codes](#error-codes)

---

## Authentication & JWT

The API uses **JWT (JSON Web Token)** authentication via `djangorestframework-simplejwt`.

### Token Flow

1. User registers or logs in
2. Server returns `access` and `refresh` tokens
3. Include `access` token in the `Authorization` header: `Bearer <access_token>`
4. When `access` token expires, use `refresh` token to get a new `access` token
5. On logout, the `refresh` token is blacklisted and cannot be reused

### Token Contents

Both `access` and `refresh` tokens contain:

- `user_id`
- `role` (patient, doctor, or admin)
- `full_name`
- Standard JWT claims (exp, iat, jti)

### Example Request with JWT

```bash
curl -X GET http://localhost:8000/api/v1/auth/profile/ \
  -H "Authorization: Bearer <access_token>"
```

---

## Response Format

All API responses follow a **standardized envelope** format:

```json
{
  "status": "success" | "error",
  "message": "Human-readable message",
  "data": { /* response data or null */ },
  "errors": { /* field-level errors or null */ }
}
```

### Success Example

```json
{
  "status": "success",
  "message": "Login successful.",
  "data": {
    "tokens": {
      "access": "eyJ0eXAiOiJKV1QiLCJhbGc...",
      "refresh": "eyJ0eXAiOiJKV1QiLCJhbGc..."
    },
    "user": {
      "id": 1,
      "username": "john_doe",
      "email": "john@example.com",
      "role": "patient",
      "first_name": "John",
      "last_name": "Doe",
      "phone_number": "+233201234567",
      "is_phone_verified": true,
      "is_email_verified": false,
      "patient_profile": {
        "blood_group": "O+",
        "allergies": "Penicillin",
        "emergency_contact_name": "Jane Doe",
        "emergency_contact_phone": "+233209876543",
        "medical_history": ""
      },
      "doctor_profile": null,
      "created_at": "2026-05-01T10:30:00Z"
    }
  },
  "errors": null
}
```

### Error Example

```json
{
  "status": "error",
  "message": "Login failed.",
  "data": null,
  "errors": {
    "login": ["No account found with these credentials."]
  }
}
```

---

## Error Handling

### HTTP Status Codes

| Status | Meaning                                                                              |
| ------ | ------------------------------------------------------------------------------------ |
| 200    | OK — Request succeeded                                                               |
| 201    | Created — Resource created (e.g., registration)                                      |
| 400    | Bad Request — Invalid input or validation failed                                     |
| 401    | Unauthorized — Missing/invalid authentication                                        |
| 403    | Forbidden — Authenticated but not allowed (e.g., non-admin accessing admin endpoint) |
| 404    | Not Found — Resource does not exist                                                  |
| 500    | Internal Server Error                                                                |

### Common Error Scenarios

**Invalid credentials:**

```json
{
  "status": "error",
  "message": "Login failed.",
  "errors": {
    "password": "Incorrect password. 2 attempt(s) remaining before lockout."
  }
}
```

**Account locked:**

```json
{
  "status": "error",
  "message": "Login failed.",
  "errors": {
    "non_field_errors": "Account locked after too many failed attempts. Try again after 14:30."
  }
}
```

**Validation error:**

```json
{
  "status": "error",
  "message": "Registration failed. Please fix the errors below.",
  "errors": {
    "email": ["An account with this email already exists."],
    "password_confirm": ["Passwords do not match."]
  }
}
```

---

## API Endpoints

### Registration

#### `POST /auth/register/`

Create a new user account and send an OTP to the provided phone number.

**Roles:** Patients and doctors can self-register. Admin accounts require an existing admin to create them.

**Request Body:**

```json
{
  "username": "john_doe",
  "email": "john@example.com",
  "phone_number": "+233201234567",
  "password": "SecurePassword123!",
  "password_confirm": "SecurePassword123!",
  "first_name": "John",
  "last_name": "Doe",
  "role": "patient",
  "gender": "male",
  "date_of_birth": "1990-05-15",
  "address": "123 Main St, Accra",

  "blood_group": "O+",
  "emergency_contact_name": "Jane Doe",
  "emergency_contact_phone": "+233209876543"
}
```

**Required Fields:**

- `username` (max 150 chars, unique)
- `email` (unique)
- `phone_number` (max 20 chars, unique, E.164 format recommended: +233...)
- `password` (must pass Django validation: min 8 chars, not all numeric, not common)
- `password_confirm` (must match password)
- `first_name` (max 150 chars)
- `last_name` (max 150 chars)
- `role` (patient | doctor | admin)

**Optional Fields (Patient):**

- `blood_group` (default: "")
- `emergency_contact_name` (default: "")
- `emergency_contact_phone` (default: "")

**Optional Fields (Doctor):**

- `specialization` (default: "")
- `medical_license_number` (default: "")
- `hospital_name` (default: "")
- `consultation_fee` (default: 0.00, in GHS)

**Optional Fields (All):**

- `gender` (male | female | other | unspecified, default: "unspecified")
- `date_of_birth` (ISO 8601 format)
- `address` (default: "")

**Response:** `201 Created`

```json
{
  "status": "success",
  "message": "Registration successful. A 4-digit OTP has been sent to your phone number. Please verify to activate your account.",
  "data": {
    "user_id": 1,
    "username": "john_doe"
  },
  "errors": null
}
```

**Next Steps:** Call `POST /auth/otp/verify/` to verify the phone number and log in automatically.

---

### OTP (One-Time Password)

#### `POST /auth/otp/send/`

Send or resend a 4-digit OTP to a user's registered phone number.

**Use Cases:**

- After registration (if the user didn't receive the initial OTP)
- Before password reset
- Future 2FA scenarios

**Request Body:**

```json
{
  "phone_number": "+233201234567",
  "purpose": "phone_reg"
}
```

**Fields:**

- `phone_number` (required): Phone number associated with the account
- `purpose` (optional):
  - `phone_reg` — Phone registration verification
  - `password_reset` — Password reset OTP
  - `login_2fa` — Two-factor authentication (future use)
  - Default: `phone_reg`

**Response:** `200 OK`

```json
{
  "status": "success",
  "message": "OTP sent to +233201234567. Valid for 5 minutes.",
  "data": null,
  "errors": null
}
```

**Errors:**

- `404` if phone number not found
- `400` if invalid request

---

#### `POST /auth/otp/verify/`

Validate an OTP code and complete the associated action.

**Request Body:**

```json
{
  "phone_number": "+233201234567",
  "code": "1234",
  "purpose": "phone_reg"
}
```

**Fields:**

- `phone_number` (required): Phone number that received the OTP
- `code` (required): 4-digit OTP code
- `purpose` (optional): Must match the purpose of the OTP. Default: `phone_reg`

**Response:** `200 OK`

```json
{
  "status": "success",
  "message": "Phone verified successfully.",
  "data": {
    "tokens": {
      "access": "eyJ0eXAiOiJKV1QiLCJhbGc...",
      "refresh": "eyJ0eXAiOiJKV1QiLCJhbGc..."
    },
    "user": {
      "id": 1,
      "username": "john_doe",
      "email": "john@example.com",
      "role": "patient",
      "phone_number": "+233201234567",
      "is_phone_verified": true,
      "patient_profile": {
        /* ... */
      },
      "created_at": "2026-05-01T10:30:00Z"
    }
  },
  "errors": null
}
```

**Errors:**

- `code: "Invalid OTP code."` — Code doesn't exist or doesn't match
- `code: "OTP has expired. Please request a new one."` — OTP older than 5 minutes

---

### Login / Logout

#### `POST /auth/login/`

Authenticate a user and return JWT tokens.

**Request Body:**

```json
{
  "login": "john_doe",
  "password": "SecurePassword123!"
}
```

**Fields:**

- `login` (required): Username, email, or phone number
- `password` (required): Account password

**Response:** `200 OK`

```json
{
  "status": "success",
  "message": "Login successful.",
  "data": {
    "tokens": {
      "access": "eyJ0eXAiOiJKV1QiLCJhbGc...",
      "refresh": "eyJ0eXAiOiJKV1QiLCJhbGc..."
    },
    "user": {
      "id": 1,
      "username": "john_doe",
      "email": "john@example.com",
      "role": "patient",
      "first_name": "John",
      "last_name": "Doe",
      "full_name": "John Doe",
      "phone_number": "+233201234567",
      "is_phone_verified": true,
      "patient_profile": {
        /* ... */
      },
      "created_at": "2026-05-01T10:30:00Z"
    }
  },
  "errors": null
}
```

**Account Lockout Policy:**

- After 3 failed login attempts, the account is locked for 15 minutes
- Lockout is cleared on successful login
- Error message includes unlock time: `"Account locked after too many failed attempts. Try again after 14:30."`

**Errors:**

- `401` — Invalid credentials or account locked

---

#### `POST /auth/logout/`

Blacklist the refresh token and log out the user.

**Authentication:** Required (Bearer token)

**Request Body:**

```json
{
  "refresh": "eyJ0eXAiOiJKV1QiLCJhbGc..."
}
```

**Fields:**

- `refresh` (required): The refresh token to blacklist

**Response:** `200 OK`

```json
{
  "status": "success",
  "message": "Logged out successfully.",
  "data": null,
  "errors": null
}
```

**After Logout:**

- The refresh token cannot be used to obtain new access tokens
- The access token remains valid until it expires (usually 5 minutes)
- User must log in again to get new tokens

---

### Password Reset

#### `POST /auth/password/reset/request/`

Initiate a password reset by sending an OTP to the user's phone.

**Request Body:**

```json
{
  "phone_number": "+233201234567"
}
```

OR

```json
{
  "email": "john@example.com"
}
```

**Fields:**

- At least one of `phone_number` or `email` is required

**Response:** `200 OK`

```json
{
  "status": "success",
  "message": "If an account exists with the provided details, a reset code has been sent.",
  "data": null,
  "errors": null
}
```

**Note:** For security (user enumeration prevention), the response is always vague whether the account exists or not.

---

#### `POST /auth/password/reset/confirm/`

Verify the OTP and set a new password.

**Request Body:**

```json
{
  "phone_number": "+233201234567",
  "code": "1234",
  "new_password": "NewSecurePassword456!",
  "confirm_password": "NewSecurePassword456!"
}
```

**Fields:**

- `phone_number` (required): User's phone number
- `code` (required): 4-digit OTP code from password reset
- `new_password` (required): New password (must meet Django validation)
- `confirm_password` (required): Must match `new_password`

**Response:** `200 OK`

```json
{
  "status": "success",
  "message": "Password reset successful. You may now log in.",
  "data": null,
  "errors": null
}
```

**Errors:**

- `400` — OTP invalid/expired or passwords don't match

---

### Profile Management

#### `GET /auth/profile/`

Retrieve the authenticated user's profile.

**Authentication:** Required (Bearer token)

**Response:** `200 OK`

```json
{
  "status": "success",
  "message": "Profile retrieved successfully.",
  "data": {
    "id": 1,
    "username": "john_doe",
    "email": "john@example.com",
    "first_name": "John",
    "last_name": "Doe",
    "full_name": "John Doe",
    "role": "patient",
    "phone_number": "+233201234567",
    "date_of_birth": "1990-05-15",
    "gender": "male",
    "address": "123 Main St, Accra",
    "profile_picture_url": "https://firebase-storage.../john.jpg",
    "is_phone_verified": true,
    "is_email_verified": false,
    "whatsapp_number": "+233201234567",
    "whatsapp_linked": false,
    "notif_push": true,
    "notif_sms": true,
    "notif_whatsapp": false,
    "patient_profile": {
      "blood_group": "O+",
      "allergies": "Penicillin",
      "emergency_contact_name": "Jane Doe",
      "emergency_contact_phone": "+233209876543",
      "medical_history": ""
    },
    "doctor_profile": null,
    "created_at": "2026-05-01T10:30:00Z"
  },
  "errors": null
}
```

---

#### `PATCH /auth/profile/`

Update the authenticated user's profile (partial update).

**Authentication:** Required (Bearer token)

**Request Body:** (all fields are optional)

```json
{
  "first_name": "Jonathan",
  "email": "jonathan@example.com",
  "profile_picture_url": "https://firebase-storage.../jonathan.jpg",
  "notif_push": false,
  "notif_sms": true,
  "notif_whatsapp": true,
  "patient_profile": {
    "blood_group": "A+",
    "allergies": "Penicillin, Sulfonamides",
    "medical_history": "Diabetes Type 2"
  }
}
```

**Fields:**

- `first_name` (string)
- `last_name` (string)
- `email` (string)
- `phone_number` (string)
- `date_of_birth` (ISO 8601)
- `gender` (male | female | other | unspecified)
- `address` (string)
- `profile_picture_url` (URL)
- `whatsapp_number` (string)
- `whatsapp_linked` (boolean)
- `notif_push` (boolean) — At least one notification channel must remain enabled
- `notif_sms` (boolean)
- `notif_whatsapp` (boolean)
- `patient_profile` (nested object, for patient users only)
  - `blood_group`
  - `allergies`
  - `emergency_contact_name`
  - `emergency_contact_phone`
  - `medical_history`
- `doctor_profile` (nested object, for doctor users only)
  - `specialization`
  - `medical_license_number`
  - `hospital_name`
  - `consultation_fee`
  - `years_of_experience`
  - `is_accepting_patients`
  - `bio`
  - `avg_consultation_minutes`

**Response:** `200 OK` — Returns updated user object (same as GET)

**Validation:**

- At least one notification channel must be enabled
- Email and phone number must be unique (if changed)

**Errors:**

- `400` — Validation failed (duplicate email/phone, invalid format, etc.)
- `401` — Not authenticated

---

### Admin User Management

#### `GET /auth/users/`

List all users (paginated). **Admin only.**

**Authentication:** Required (Bearer token with `role=admin`)

**Query Parameters:**

- `page` (integer, optional): Page number (default: 1)
- `page_size` (integer, optional): Items per page (default: 10)
- `role` (string, optional): Filter by role (patient, doctor, admin)
- `search` (string, optional): Search by username, email, or phone

**Example:**

```
GET /auth/users/?page=2&role=patient&search=john
```

**Response:** `200 OK`

```json
{
  "status": "success",
  "message": "Users retrieved successfully.",
  "data": {
    "count": 50,
    "next": "http://localhost:8000/api/v1/auth/users/?page=3",
    "previous": "http://localhost:8000/api/v1/auth/users/?page=1",
    "results": [
      {
        "id": 1,
        "username": "john_doe",
        "email": "john@example.com",
        "role": "patient",
        "first_name": "John",
        "full_name": "John Doe",
        "phone_number": "+233201234567",
        "is_phone_verified": true,
        "created_at": "2026-05-01T10:30:00Z"
      },
      {
        /* ... */
      }
    ]
  },
  "errors": null
}
```

**Errors:**

- `403` — User is not an admin

---

#### `GET /auth/users/<id>/`

Retrieve a specific user's profile. **Admin only.**

**Authentication:** Required (Bearer token with `role=admin`)

**Path Parameters:**

- `id` (integer): User ID

**Response:** `200 OK` — Returns full user object (same as profile GET)

**Errors:**

- `404` — User not found
- `403` — Not an admin

---

#### `PATCH /auth/users/<id>/`

Update any user's profile. **Admin only.**

**Authentication:** Required (Bearer token with `role=admin`)

**Path Parameters:**

- `id` (integer): User ID

**Request Body:** (same fields as profile update PATCH)

**Response:** `200 OK` — Returns updated user object

**Errors:**

- `404` — User not found
- `403` — Not an admin

---

#### `DELETE /auth/users/<id>/`

Deactivate a user account. **Admin only.**

**Authentication:** Required (Bearer token with `role=admin`)

**Path Parameters:**

- `id` (integer): User ID

**Response:** `200 OK`

```json
{
  "status": "success",
  "message": "User deactivated successfully.",
  "data": null,
  "errors": null
}
```

**Note:** Deactivated users cannot log in. Their data is not deleted.

**Errors:**

- `404` — User not found
- `403` — Not an admin

---

### Token Refresh

#### `POST /auth/token/refresh/`

Get a new access token using a refresh token.

**Request Body:**

```json
{
  "refresh": "eyJ0eXAiOiJKV1QiLCJhbGc..."
}
```

**Fields:**

- `refresh` (required): The refresh token

**Response:** `200 OK`

```json
{
  "status": "success",
  "message": "Token refreshed successfully.",
  "data": {
    "access": "eyJ0eXAiOiJKV1QiLCJhbGc..."
  },
  "errors": null
}
```

**Note:** The refresh token is not rotated; the same refresh token can be used multiple times until it expires or is blacklisted.

---

## Data Models

### User

| Field                 | Type     | Description                                      |
| --------------------- | -------- | ------------------------------------------------ |
| `id`                  | integer  | Unique user ID (primary key)                     |
| `username`            | string   | Unique username (max 150 chars)                  |
| `email`               | string   | Unique email address                             |
| `first_name`          | string   | User's first name (max 150 chars)                |
| `last_name`           | string   | User's last name (max 150 chars)                 |
| `full_name`           | string   | Computed: `first_name` + `last_name` (read-only) |
| `phone_number`        | string   | Unique phone number (E.164 format recommended)   |
| `date_of_birth`       | date     | ISO 8601 format (nullable)                       |
| `gender`              | string   | male \| female \| other \| unspecified           |
| `address`             | string   | Street address (multiline)                       |
| `profile_picture_url` | string   | Firebase Storage URL (nullable)                  |
| `role`                | string   | patient \| doctor \| admin                       |
| `is_phone_verified`   | boolean  | Phone number verified via OTP                    |
| `is_email_verified`   | boolean  | Email verified (currently unused)                |
| `is_active`           | boolean  | Account active (not deactivated)                 |
| `whatsapp_number`     | string   | Separate WhatsApp number (nullable)              |
| `whatsapp_linked`     | boolean  | WhatsApp integration linked                      |
| `notif_push`          | boolean  | Receive push notifications                       |
| `notif_sms`           | boolean  | Receive SMS notifications                        |
| `notif_whatsapp`      | boolean  | Receive WhatsApp notifications                   |
| `created_at`          | datetime | Account creation timestamp (read-only)           |
| `updated_at`          | datetime | Last update timestamp (read-only)                |

### PatientProfile (nested in User)

| Field                     | Type   | Description                  |
| ------------------------- | ------ | ---------------------------- |
| `blood_group`             | string | Blood type (O+, A-, etc.)    |
| `allergies`               | string | Comma-separated allergy list |
| `emergency_contact_name`  | string | Name of emergency contact    |
| `emergency_contact_phone` | string | Phone of emergency contact   |
| `medical_history`         | string | Medical history notes        |

### DoctorProfile (nested in User)

| Field                      | Type    | Description                                            |
| -------------------------- | ------- | ------------------------------------------------------ |
| `specialization`           | string  | Medical specialization                                 |
| `medical_license_number`   | string  | License number                                         |
| `hospital_name`            | string  | Primary hospital affiliation                           |
| `consultation_fee`         | decimal | Fee in GHS (2 decimal places)                          |
| `years_of_experience`      | integer | Years in practice                                      |
| `is_accepting_patients`    | boolean | Currently accepting new patients                       |
| `bio`                      | string  | Professional biography                                 |
| `avg_consultation_minutes` | integer | Avg consultation duration (for wait time calculations) |

### OTPVerification (internal)

| Field        | Type     | Description                                |
| ------------ | -------- | ------------------------------------------ |
| `user_id`    | integer  | Associated user                            |
| `code`       | string   | 4-digit OTP code                           |
| `purpose`    | string   | phone_reg \| password_reset \| login_2fa   |
| `is_used`    | boolean  | Code already consumed                      |
| `expires_at` | datetime | Expiration time (5 minutes after creation) |
| `created_at` | datetime | Creation timestamp                         |

### AuditLog (internal)

| Field         | Type     | Description                                           |
| ------------- | -------- | ----------------------------------------------------- |
| `id`          | integer  | Log entry ID                                          |
| `user_id`     | integer  | Associated user (nullable)                            |
| `event_type`  | string   | login \| logout \| register \| password_reset \| etc. |
| `description` | string   | Human-readable description                            |
| `ip_address`  | string   | Request IP address                                    |
| `user_agent`  | string   | Request user agent                                    |
| `metadata`    | object   | Event-specific metadata (JSON)                        |
| `created_at`  | datetime | Log timestamp                                         |

---

## Rate Limiting & Throttling

The API implements rate limiting on sensitive endpoints:

| Endpoint            | Limit       | Window               |
| ------------------- | ----------- | -------------------- |
| `/auth/register/`   | 5 requests  | Per hour per IP      |
| `/auth/login/`      | 10 requests | Per minute per user  |
| `/auth/otp/send/`   | 3 requests  | Per minute per phone |
| `/auth/otp/verify/` | 10 requests | Per minute per user  |

**Rate Limit Headers:**

- `X-RateLimit-Limit` — Total requests allowed
- `X-RateLimit-Remaining` — Requests remaining
- `X-RateLimit-Reset` — Unix timestamp when limit resets

**Response when limit exceeded:** `429 Too Many Requests`

```json
{
  "status": "error",
  "message": "Request throttled. Please try again later.",
  "errors": {
    "non_field_errors": "Expected available in 45 seconds."
  }
}
```

---

## Error Codes

### Authentication Errors

| Error               | Status | Description                                   |
| ------------------- | ------ | --------------------------------------------- |
| Invalid credentials | 401    | Username/email/phone or password is incorrect |
| Account locked      | 401    | Account locked after 3 failed login attempts  |
| Account deactivated | 401    | Account has been disabled by admin            |
| Missing token       | 401    | No authorization header provided              |
| Invalid token       | 401    | Token is malformed or expired                 |
| Token blacklisted   | 401    | Token was blacklisted on logout               |

### Validation Errors

| Error              | Status | Description                            |
| ------------------ | ------ | -------------------------------------- |
| Duplicate username | 400    | Username already exists                |
| Duplicate email    | 400    | Email already in use                   |
| Duplicate phone    | 400    | Phone number already in use            |
| Invalid email      | 400    | Email format invalid                   |
| Weak password      | 400    | Password doesn't meet requirements     |
| Password mismatch  | 400    | Passwords don't match                  |
| Invalid OTP        | 400    | OTP code is wrong or expired           |
| Invalid role       | 400    | Role must be patient, doctor, or admin |

### Authorization Errors

| Error            | Status | Description                                      |
| ---------------- | ------ | ------------------------------------------------ |
| Admin only       | 403    | Endpoint requires admin role                     |
| Not your profile | 403    | Cannot modify another user's profile (non-admin) |

### Server Errors

| Error               | Status | Description                    |
| ------------------- | ------ | ------------------------------ |
| Internal error      | 500    | Unexpected server error        |
| Service unavailable | 503    | Server temporarily unavailable |

---

## Quick Start for Frontend

### 1. User Registration

```bash
POST /auth/register/
{
  "username": "john_doe",
  "email": "john@example.com",
  "phone_number": "+233201234567",
  "password": "SecurePassword123!",
  "password_confirm": "SecurePassword123!",
  "first_name": "John",
  "last_name": "Doe",
  "role": "patient"
}
# Response: User created, OTP sent to phone
```

### 2. Verify Phone with OTP

```bash
POST /auth/otp/verify/
{
  "phone_number": "+233201234567",
  "code": "1234",
  "purpose": "phone_reg"
}
# Response: Includes access + refresh tokens + user data
```

### 3. Use Access Token

```bash
GET /auth/profile/
-H "Authorization: Bearer {access_token}"
# Response: User's profile data
```

### 4. Refresh Token When Expired

```bash
POST /auth/token/refresh/
{
  "refresh": "{refresh_token}"
}
# Response: New access token
```

### 5. Logout

```bash
POST /auth/logout/
{
  "refresh": "{refresh_token}"
}
# Response: Token blacklisted, user logged out
```

---

## Support

For issues or questions, contact the backend team or check the interactive API docs at:

- **Swagger UI:** `http://localhost:8000/api/docs/`
- **ReDoc:** `http://localhost:8000/api/redoc/`
- **OpenAPI Schema:** `http://localhost:8000/api/schema/`
