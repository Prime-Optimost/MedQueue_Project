"""
accounts/urls.py

All URL patterns for the accounts / authentication module.
Include in the project root urls.py as:
    path("api/v1/auth/", include("apps.accounts.urls")),
"""

from django.urls import path

from .views.accounts import (
    AdminCreateUserView,
    AdminDashboardStatsView,
    AdminUserDetailView,
    AdminUserListView,
    LoginView,
    LogoutView,
    PasswordResetConfirmView,
    PasswordResetRequestView,
    ProfileView,
    RegisterView,
    ResendOTPView,
    SendOTPView,
    TokenRefreshEnvelopeView,
    VerifyOTPView,
)


from .views.appointments import (
    AdminAppointmentOverrideView,
    AdminDoctorScheduleDetailView,
    AdminDoctorScheduleView,
    AppointmentDetailView,
    AppointmentHistoryView,
    BookAppointmentView,
    CancelAppointmentView,
    DoctorAvailabilityDatesView,
    DoctorDateAvailabilityDetailView,
    DoctorDateAvailabilityListView,
    DoctorListView,
    DoctorMarkStatusView,
    DoctorScheduleListView,
    DoctorSlotListView,
    RescheduleAppointmentView,
)

from .views.availability import (
    DoctorMyAvailabilityView,
    DoctorMyAvailabilityDetailView,
)


from .views.queues import (
    AdminForceEntryStatusView,
    AdminQueueOverviewView,
    AdminAggregateStatsView,
    AdminDailyStatsView,
    DoctorCallNextView,
    DoctorMarkCompleteView,
    DoctorPauseQueueView,
    DoctorQueueView,
    DoctorResumeQueueView,
    DoctorCloseQueueView,
    PatientLeaveQueueView,
    PatientQueueStatusView,
)


from .views.emergencies import (
    ActiveSOSStatusView,
    AdminEmergencyDetailView,
    AdminEmergencyLogView,
    AdminEmergencySummaryView,
    AdminUpdateSOSStatusView,
    CancelSOSView,
    EmergencyContactDetailView,
    EmergencyContactListView,
    PatientEmergencyHistoryView,
    TriggerSOSView,
)


from .views.notifications import (
    NotificationDetailView,
    NotificationListView,
)


from .views.reports import (
    AdminDoctorReportView,
    AdminGeneralReportView,
    AdminPatientReportView,
)



app_name = "base"

urlpatterns = [
    # ------------------------------------------------------------------ #
    # Registration                                                         #
    # ------------------------------------------------------------------ #
    path(
        "register/",
        RegisterView.as_view(),
        name="register",
    ),

    # ------------------------------------------------------------------ #
    # OTP                                                                  #
    # ------------------------------------------------------------------ #
    path(
        "otp/send/",
        SendOTPView.as_view(),
        name="otp-send",
    ),
    path(
        "otp/verify/",
        VerifyOTPView.as_view(),
        name="otp-verify",
    ),
    path(
        "otp/resend/",
        ResendOTPView.as_view(),
        name="otp-resend",
    ),

    # ------------------------------------------------------------------ #
    # Login / Logout                                                       #
    # ------------------------------------------------------------------ #
    path(
        "login/",
        LoginView.as_view(),
        name="login",
    ),
    path(
        "logout/",
        LogoutView.as_view(),
        name="logout",
    ),

    # ------------------------------------------------------------------ #
    # JWT Token Management                                                 #
    # ------------------------------------------------------------------ #
    path(
        "token/refresh/",
        TokenRefreshEnvelopeView.as_view(),
        name="token-refresh",
    ),

    # ------------------------------------------------------------------ #
    # Password Reset                                                       #
    # ------------------------------------------------------------------ #
    path(
        "password/reset/request/",
        PasswordResetRequestView.as_view(),
        name="password-reset-request",
    ),
    path(
        "password/reset/confirm/",
        PasswordResetConfirmView.as_view(),
        name="password-reset-confirm",
    ),

    # ------------------------------------------------------------------ #
    # Own Profile (any authenticated user)                                 #
    # ------------------------------------------------------------------ #
    path(
        "profile/",
        ProfileView.as_view(),
        name="profile",
    ),

    # ------------------------------------------------------------------ #
    # Admin: User Management                                               #
    # ------------------------------------------------------------------ #
    path(
        "users/",
        AdminUserListView.as_view(),
        name="admin-user-list",
    ),
    # POST /auth/admin/users/  — admin creates a doctor/patient/admin account
    path(
        "admin/users/",
        AdminCreateUserView.as_view(),
        name="admin-user-create",
    ),
    path(
        "users/<int:pk>/",
        AdminUserDetailView.as_view(),
        name="admin-user-detail",
    ),

    # ------------------------------------------------------------------ #
    # Admin: dashboard system overview stats                              #
    # ------------------------------------------------------------------ #
    path(
        "admin/dashboard/stats/",
        AdminDashboardStatsView.as_view(),
        name="admin-dashboard-stats",
    ),

    # ------------------------------------------------------------------ #
    # Admin: reports (general / patient / doctor)                         #
    # ------------------------------------------------------------------ #
    path(
        "admin/reports/general/",
        AdminGeneralReportView.as_view(),
        name="admin-report-general",
    ),
    path(
        "admin/reports/patient/",
        AdminPatientReportView.as_view(),
        name="admin-report-patient",
    ),
    path(
        "admin/reports/doctor/",
        AdminDoctorReportView.as_view(),
        name="admin-report-doctor",
    ),
    
    
        # ------------------------------------------------------------------ #
    # FR-2.1  Browse Doctors                                               #
    # ------------------------------------------------------------------ #
    # GET  /appointments/doctors/
    path(
        "doctors/",
        DoctorListView.as_view(),
        name="doctor-list",
    ),

    # ------------------------------------------------------------------ #
    # FR-2.2  Real-Time Slot Availability                                  #
    # ------------------------------------------------------------------ #
    # GET  /appointments/doctors/<doctor_id>/slots/?date=YYYY-MM-DD
    path(
        "doctors/<int:doctor_id>/slots/",
        DoctorSlotListView.as_view(),
        name="doctor-slots",
    ),
    # GET /appointments/doctors/<doctor_id>/availability/?from=...&to=...
    path(
        "doctors/<int:doctor_id>/availability/",
        DoctorAvailabilityDatesView.as_view(),
        name="doctor-availability-dates",
    ),

    # ------------------------------------------------------------------ #
    # FR-2.3  Book Appointment                                             #
    # ------------------------------------------------------------------ #
    # POST /appointments/book/
    path(
        "book/",
        BookAppointmentView.as_view(),
        name="book",
    ),

    # ------------------------------------------------------------------ #
    # FR-2.3  Appointment Detail                                           #
    # ------------------------------------------------------------------ #
    # GET  /appointments/<pk>/
    path(
        "<int:pk>/",
        AppointmentDetailView.as_view(),
        name="detail",
    ),

    # ------------------------------------------------------------------ #
    # FR-2.5  Cancel Appointment                                           #
    # ------------------------------------------------------------------ #
    # POST /appointments/<pk>/cancel/
    path(
        "<int:pk>/cancel/",
        CancelAppointmentView.as_view(),
        name="cancel",
    ),

    # ------------------------------------------------------------------ #
    # FR-2.6  Reschedule Appointment                                       #
    # ------------------------------------------------------------------ #
    # POST /appointments/<pk>/reschedule/
    path(
        "<int:pk>/reschedule/",
        RescheduleAppointmentView.as_view(),
        name="reschedule",
    ),

    # ------------------------------------------------------------------ #
    # FR-2.7  Doctor: My Schedule                                          #
    # ------------------------------------------------------------------ #
    # GET  /appointments/doctor/schedule/?date=YYYY-MM-DD&range=week
    path(
        "doctor/schedule/",
        DoctorScheduleListView.as_view(),
        name="doctor-schedule",
    ),

    # FR-2.7  Doctor: Mark Complete / No-Show
    # POST /appointments/<pk>/mark/
    path(
        "<int:pk>/mark/",
        DoctorMarkStatusView.as_view(),
        name="doctor-mark-status",
    ),

    # ------------------------------------------------------------------ #
    # FR-2.8  Appointment History                                          #
    # ------------------------------------------------------------------ #
    # GET /appointments/history/
    path(
        "history/",
        AppointmentHistoryView.as_view(),
        name="history",
    ),

    # ------------------------------------------------------------------ #
    # FR-7.2  Admin: Doctor Schedule CRUD                                  #
    # ------------------------------------------------------------------ #
    # GET, POST /appointments/admin/schedules/
    path(
        "admin/schedules/",
        AdminDoctorScheduleView.as_view(),
        name="admin-schedule-list",
    ),
    # GET, PATCH, DELETE /appointments/admin/schedules/<pk>/
    path(
        "admin/schedules/<int:pk>/",
        AdminDoctorScheduleDetailView.as_view(),
        name="admin-schedule-detail",
    ),

    # ------------------------------------------------------------------ #
    # Doctor: Self-Serve Availability CRUD                                #
    # ------------------------------------------------------------------ #
    # GET, POST /availability/my/
    path(
        "availability/my/",
        DoctorMyAvailabilityView.as_view(),
        name="doctor-availability-my",
    ),
    # PATCH, DELETE /availability/my/<pk>/
    path(
        "availability/my/<int:pk>/",
        DoctorMyAvailabilityDetailView.as_view(),
        name="doctor-availability-my-detail",
    ),

    # ------------------------------------------------------------------ #
    # Doctor: Date-specific availability overrides                        #
    # ------------------------------------------------------------------ #
    # GET, POST /availability/dates/
    path(
        "availability/dates/",
        DoctorDateAvailabilityListView.as_view(),
        name="doctor-date-availability-list",
    ),
    # PATCH, DELETE /availability/dates/<pk>/
    path(
        "availability/dates/<int:pk>/",
        DoctorDateAvailabilityDetailView.as_view(),
        name="doctor-date-availability-detail",
    ),

    # ------------------------------------------------------------------ #
    # FR-2.10  Admin: Override Any Appointment                             #
    # ------------------------------------------------------------------ #
    # POST   /appointments/admin/override/
    path(
        "admin/override/",
        AdminAppointmentOverrideView.as_view(),
        name="admin-override-create",
    ),
    # PATCH, DELETE /appointments/admin/override/<pk>/
    path(
        "admin/override/<int:pk>/",
        AdminAppointmentOverrideView.as_view(),
        name="admin-override-detail",
    ),
    
        # ------------------------------------------------------------------ #
    # FR-3.2  Patient: view own position                                   #
    # GET  /queue/my-position/?date=YYYY-MM-DD                            #
    # ------------------------------------------------------------------ #
    path(
        "my-position/",
        PatientQueueStatusView.as_view(),
        name="patient-position",
    ),

    # ------------------------------------------------------------------ #
    # FR-3.6  Patient: leave queue voluntarily                             #
    # POST /queue/leave/                                                   #
    # ------------------------------------------------------------------ #
    path(
        "leave/",
        PatientLeaveQueueView.as_view(),
        name="patient-leave",
    ),

    # ------------------------------------------------------------------ #
    # FR-3.5  Doctor: view full day queue                                  #
    # GET  /queue/doctor/?date=YYYY-MM-DD                                  #
    # ------------------------------------------------------------------ #
    path(
        "doctor/",
        DoctorQueueView.as_view(),
        name="doctor-queue",
    ),

    # ------------------------------------------------------------------ #
    # FR-3.5  Doctor: call next patient                                    #
    # POST /queue/doctor/call-next/                                        #
    # ------------------------------------------------------------------ #
    path(
        "doctor/call-next/",
        DoctorCallNextView.as_view(),
        name="doctor-call-next",
    ),

    # ------------------------------------------------------------------ #
    # FR-3.4  Doctor: mark consultation complete                           #
    # POST /queue/doctor/entries/<entry_id>/complete/                      #
    # ------------------------------------------------------------------ #
    path(
        "doctor/entries/<int:entry_id>/complete/",
        DoctorMarkCompleteView.as_view(),
        name="doctor-mark-complete",
    ),

    # ------------------------------------------------------------------ #
    # FR-3.5  Doctor: pause / resume / close queue                        #
    # ------------------------------------------------------------------ #
    path(
        "doctor/pause/",
        DoctorPauseQueueView.as_view(),
        name="doctor-pause",
    ),
    path(
        "doctor/resume/",
        DoctorResumeQueueView.as_view(),
        name="doctor-resume",
    ),
    path(
        "doctor/close/",
        DoctorCloseQueueView.as_view(),
        name="doctor-close",
    ),

    # ------------------------------------------------------------------ #
    # FR-7.3  Admin: live queue overview (all doctors)                     #
    # GET  /queue/admin/overview/?date=YYYY-MM-DD                         #
    # ------------------------------------------------------------------ #
    path(
        "admin/overview/",
        AdminQueueOverviewView.as_view(),
        name="admin-overview",
    ),

    # ------------------------------------------------------------------ #
    # FR-3.7  Admin: analytics                                             #
    # ------------------------------------------------------------------ #
    path(
        "admin/stats/daily/",
        AdminDailyStatsView.as_view(),
        name="admin-daily-stats",
    ),
    path(
        "admin/stats/aggregate/",
        AdminAggregateStatsView.as_view(),
        name="admin-aggregate-stats",
    ),

    # ------------------------------------------------------------------ #
    # Admin: force-update any entry status                                 #
    # PATCH /queue/admin/entries/<entry_id>/                               #
    # ------------------------------------------------------------------ #
    path(
        "admin/entries/<int:entry_id>/",
        AdminForceEntryStatusView.as_view(),
        name="admin-force-entry",
    ),
    
    
    # ------------------------------------------------------------------ #
    # FR-5.3 / FR-5.4  Patient: trigger SOS                               #
    # POST /emergency/sos/                                                  #
    # ------------------------------------------------------------------ #
    path(
        "sos/",
        TriggerSOSView.as_view(),
        name="trigger-sos",
    ),

    # ------------------------------------------------------------------ #
    # FR-5.7  Patient: view active SOS status                              #
    # GET /emergency/sos/active/                                            #
    # ------------------------------------------------------------------ #
    path(
        "sos/active/",
        ActiveSOSStatusView.as_view(),
        name="active-sos",
    ),

    # ------------------------------------------------------------------ #
    # FR-5.2  Patient: cancel pending SOS                                  #
    # POST /emergency/sos/<pk>/cancel/                                     #
    # ------------------------------------------------------------------ #
    path(
        "sos/<int:pk>/cancel/",
        CancelSOSView.as_view(),
        name="cancel-sos",
    ),

    # ------------------------------------------------------------------ #
    # FR-5.8  Patient: SOS history                                         #
    # GET /emergency/history/                                               #
    # ------------------------------------------------------------------ #
    path(
        "history/",
        PatientEmergencyHistoryView.as_view(),
        name="patient-history",
    ),

    # ------------------------------------------------------------------ #
    # FR-5.7  Admin / Doctor: update SOS status                            #
    # PATCH /emergency/admin/<pk>/status/                                   #
    # ------------------------------------------------------------------ #
    path(
        "admin/<int:pk>/status/",
        AdminUpdateSOSStatusView.as_view(),
        name="admin-update-status",
    ),

    # ------------------------------------------------------------------ #
    # FR-7.6  Admin: full emergency log                                     #
    # GET /emergency/admin/log/                                             #
    # ------------------------------------------------------------------ #
    path(
        "admin/log/",
        AdminEmergencyLogView.as_view(),
        name="admin-log",
    ),

    # ------------------------------------------------------------------ #
    # FR-7.6  Admin: single SOS detail (with full timeline)                #
    # GET /emergency/admin/<pk>/                                            #
    # ------------------------------------------------------------------ #
    path(
        "admin/<int:pk>/",
        AdminEmergencyDetailView.as_view(),
        name="admin-detail",
    ),

    # ------------------------------------------------------------------ #
    # FR-7.6  Admin: aggregate summary stats                               #
    # GET /emergency/admin/summary/                                         #
    # ------------------------------------------------------------------ #
    path(
        "admin/summary/",
        AdminEmergencySummaryView.as_view(),
        name="admin-summary",
    ),

    # ------------------------------------------------------------------ #
    # FR-5.5  Admin: manage emergency contacts                             #
    # GET / POST /emergency/admin/contacts/                                 #
    # ------------------------------------------------------------------ #
    path(
        "admin/contacts/",
        EmergencyContactListView.as_view(),
        name="admin-contacts-list",
    ),

    # GET / PATCH / DELETE /emergency/admin/contacts/<pk>/
    path(
        "admin/contacts/<int:pk>/",
        EmergencyContactDetailView.as_view(),
        name="admin-contacts-detail",
    ),

    # ------------------------------------------------------------------ #
    # In-App Notifications (patient / doctor / admin)                     #
    # ------------------------------------------------------------------ #
    # GET  /auth/notifications/
    # POST /auth/notifications/  (mark read: {"id": X} or {"all": true})
    path(
        "notifications/",
        NotificationListView.as_view(),
        name="notification-list",
    ),
    # DELETE /auth/notifications/<pk>/
    path(
        "notifications/<int:pk>/",
        NotificationDetailView.as_view(),
        name="notification-detail",
    ),

]

