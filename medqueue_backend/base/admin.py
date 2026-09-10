"""
accounts/admin.py
"""

from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from django.utils.translation import gettext_lazy as _
from django.utils.html import format_html
from .models import (
    AuditLog, DoctorProfile, OTPVerification, 
    PatientProfile, User, Appointment, AppointmentStatus, 
    DoctorAvailabilityOverride, DoctorSchedule, TimeSlot, QueueEntry, QueueEntryStatus, 
    QueuePauseLog, QueueSession, EmergencyContact, EmergencyRequest, 
    EmergencyStatusLog
    )

    

class PatientProfileInline(admin.StackedInline):
    model     = PatientProfile
    extra     = 0
    can_delete= False


class DoctorProfileInline(admin.StackedInline):
    model     = DoctorProfile
    extra     = 0
    can_delete= False


@admin.register(User)
class UserAdmin(BaseUserAdmin):
    list_display  = ("username", "email", "role", "phone_number",
                     "is_phone_verified", "is_active", "failed_login_attempts")
    list_filter   = ("role", "is_active", "is_phone_verified", "gender")
    search_fields = ("username", "email", "phone_number", "first_name", "last_name")
    ordering      = ("-created_at",)
    inlines       = [PatientProfileInline, DoctorProfileInline]

    fieldsets = BaseUserAdmin.fieldsets + (
        (_("MedQueue GH"), {
            "fields": (
                "role", "phone_number", "date_of_birth", "gender", "address",
                "profile_picture", "is_phone_verified", "is_email_verified",
                "whatsapp_number", "whatsapp_linked",
                "failed_login_attempts", "lockout_until",
                "notif_push", "notif_sms", "notif_whatsapp",
            )
        }),
    )
        


@admin.register(OTPVerification)
class OTPVerificationAdmin(admin.ModelAdmin):
    list_display  = ("user", "purpose", "is_used", "expires_at", "created_at")
    list_filter   = ("purpose", "is_used")
    search_fields = ("user__username", "user__phone_number")
    readonly_fields = ("created_at",)


@admin.register(AuditLog)
class AuditLogAdmin(admin.ModelAdmin):
    list_display  = ("event_type", "user", "ip_address", "created_at")
    list_filter   = ("event_type",)
    search_fields = ("user__username", "ip_address", "description")
    readonly_fields = ("user", "event_type", "description", "ip_address",
                       "user_agent", "metadata", "created_at")

    def has_add_permission(self, request):
        return False      # audit logs are system-generated only

    def has_change_permission(self, request, obj=None):
        return False
    
    

@admin.register(DoctorSchedule)
class DoctorScheduleAdmin(admin.ModelAdmin):
    list_display  = ("doctor", "get_day", "start_time", "end_time",
                     "slot_duration_minutes", "max_patients_per_day", "is_active")
    list_filter   = ("is_active", "day_of_week")
    search_fields = ("doctor__first_name", "doctor__last_name", "doctor__username")
    ordering      = ("doctor", "day_of_week")

    def get_day(self, obj):
        return obj.get_day_of_week_display()
    get_day.short_description = "Day"


@admin.register(DoctorAvailabilityOverride)
class DoctorAvailabilityOverrideAdmin(admin.ModelAdmin):
    list_display  = ("doctor", "date", "override_type", "start_time", "end_time",
                     "slot_duration_minutes", "max_patients_per_day", "created_at")
    list_filter   = ("override_type", "date")
    search_fields = ("doctor__first_name", "doctor__last_name", "doctor__username")
    ordering      = ("doctor", "date")
    readonly_fields = ("created_at", "updated_at")


@admin.register(TimeSlot)
class TimeSlotAdmin(admin.ModelAdmin):
    list_display  = ("doctor", "date", "start_time", "end_time", "status_badge")
    list_filter   = ("status", "date")
    search_fields = ("doctor__first_name", "doctor__last_name")
    ordering      = ("date", "start_time")
    date_hierarchy = "date"

    def status_badge(self, obj):
        colours = {
            "available": "#27AE60",
            "booked":    "#E74C3C",
            "blocked":   "#95A5A6",
        }
        colour = colours.get(obj.status, "#000")
        return format_html(
            '<span style="background:{};color:#fff;padding:2px 8px;'
            'border-radius:4px;">{}</span>',
            colour,
            obj.status.upper(),
        )
    status_badge.short_description = "Status"


@admin.register(Appointment)
class AppointmentAdmin(admin.ModelAdmin):
    list_display  = ("id", "patient", "doctor", "appointment_date",
                     "appointment_time", "status", "created_at")
    list_filter   = ("status", "appointment_date")
    search_fields = ("patient__first_name", "patient__last_name",
                     "doctor__first_name",  "doctor__last_name")
    ordering      = ("-appointment_date", "-appointment_time")
    date_hierarchy = "appointment_date"
    readonly_fields = ("created_at", "updated_at", "rescheduled_from")

    fieldsets = (
        ("Core", {
            "fields": ("patient", "doctor", "slot",
                       "appointment_date", "appointment_time", "status")
        }),
        ("Details", {
            "fields": ("reason", "notes", "cancellation_reason", "cancelled_by",
                       "booked_by_reception")
        }),
        ("Reminders", {
            "fields": ("reminder_24h_sent", "reminder_30m_sent"),
            "classes": ("collapse",),
        }),
        ("Metadata", {
            "fields": ("rescheduled_from", "created_at", "updated_at"),
            "classes": ("collapse",),
        }),
    )    
    
    

class QueueEntryInline(admin.TabularInline):
    model        = QueueEntry
    extra        = 0
    readonly_fields = (
        "queue_number", "patient", "status",
        "called_at", "completed_at", "notified_2away",
    )
    fields       = readonly_fields
    can_delete   = False
    ordering     = ("queue_number",)


@admin.register(QueueSession)
class QueueSessionAdmin(admin.ModelAdmin):
    list_display  = (
        "doctor", "date", "status_badge", "current_position",
        "waiting_count_display", "served_count_display", "total_pause_minutes",
    )
    list_filter   = ("status", "date")
    search_fields = ("doctor__first_name", "doctor__last_name")
    ordering      = ("-date", "doctor")
    date_hierarchy= "date"
    readonly_fields = ("created_at", "updated_at", "total_pause_minutes")
    inlines       = [QueueEntryInline]

    def status_badge(self, obj):
        colours = {
            "active": "#27AE60",
            "paused": "#E67E22",
            "closed": "#95A5A6",
        }
        return format_html(
            '<span style="background:{};color:#fff;padding:2px 8px;border-radius:4px">{}</span>',
            colours.get(obj.status, "#000"),
            obj.status.upper(),
        )
    status_badge.short_description = "Status"

    def waiting_count_display(self, obj):
        return obj.waiting_count
    waiting_count_display.short_description = "Waiting"

    def served_count_display(self, obj):
        return obj.served_count
    served_count_display.short_description = "Served"


@admin.register(QueueEntry)
class QueueEntryAdmin(admin.ModelAdmin):
    list_display  = (
        "queue_number", "patient", "session",
        "status", "positions_ahead_display", "called_at", "completed_at",
    )
    list_filter   = ("status",)
    search_fields = ("patient__first_name", "patient__last_name")
    ordering      = ("session__date", "queue_number")
    readonly_fields = ("created_at", "updated_at", "queue_number")

    def positions_ahead_display(self, obj):
        return obj.positions_ahead
    positions_ahead_display.short_description = "Ahead"


@admin.register(QueuePauseLog)
class QueuePauseLogAdmin(admin.ModelAdmin):
    list_display  = ("session", "doctor", "paused_at", "resumed_at", "duration_minutes", "reason")
    list_filter   = ("session__date",)
    readonly_fields = ("paused_at", "resumed_at", "session", "doctor")

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False

    def duration_minutes(self, obj):
        return obj.duration_minutes
    duration_minutes.short_description = "Duration (min)"    
    
    
    

class EmergencyStatusLogInline(admin.TabularInline):
    model           = EmergencyStatusLog
    extra           = 0
    readonly_fields = ("previous_status", "new_status", "changed_by", "notes", "created_at")
    fields          = readonly_fields
    can_delete      = False
    ordering        = ("created_at",)


@admin.register(EmergencyRequest)
class EmergencyRequestAdmin(admin.ModelAdmin):
    list_display    = (
        "id", "patient", "emergency_type", "status_badge",
        "confirmed_at", "response_time_seconds", "maps_link", "admin_notified",
    )
    list_filter     = ("status", "emergency_type", "confirmed_at")
    search_fields   = ("patient__first_name", "patient__last_name", "patient__phone_number")
    ordering        = ("-confirmed_at",)
    date_hierarchy  = "confirmed_at"
    readonly_fields = (
        "confirmed_at", "dispatched_at", "resolved_at",
        "response_time_seconds", "admin_notified", "patient_ack_sent",
        "maps_link", "created_at", "updated_at",
    )
    inlines         = [EmergencyStatusLogInline]

    fieldsets = (
        ("Patient & Location", {
            "fields": (
                "patient", "latitude", "longitude",
                "gps_accuracy_meters", "maps_link",
            )
        }),
        ("Emergency Details", {
            "fields": ("emergency_type", "description", "status")
        }),
        ("Response", {
            "fields": (
                "handled_by", "ambulance_plate", "ambulance_eta_minutes",
                "resolution_notes",
            )
        }),
        ("Timing", {
            "fields": (
                "confirmed_at", "dispatched_at", "resolved_at",
                "response_time_seconds",
            ),
            "classes": ("collapse",),
        }),
        ("Notifications", {
            "fields": ("admin_notified", "patient_ack_sent"),
            "classes": ("collapse",),
        }),
    )

    def status_badge(self, obj):
        colours = {
            "pending":    "#E67E22",
            "dispatched": "#2980B9",
            "resolved":   "#27AE60",
            "cancelled":  "#95A5A6",
            "false_alarm":"#BDC3C7",
        }
        return format_html(
            '<span style="background:{};color:#fff;padding:2px 8px;'
            'border-radius:4px;font-weight:600">{}</span>',
            colours.get(obj.status, "#000"),
            obj.status.upper(),
        )
    status_badge.short_description = "Status"

    def maps_link(self, obj):
        url = obj.maps_url
        if url:
            return format_html('<a href="{}" target="_blank">📍 Open in Maps</a>', url)
        return "No GPS"
    maps_link.short_description = "Location"


@admin.register(EmergencyContact)
class EmergencyContactAdmin(admin.ModelAdmin):
    list_display  = ("name", "contact_type", "phone_number", "email", "is_active")
    list_filter   = ("contact_type", "is_active")
    search_fields = ("name", "phone_number", "email")
    ordering      = ("contact_type", "name")


@admin.register(EmergencyStatusLog)
class EmergencyStatusLogAdmin(admin.ModelAdmin):
    list_display  = ("request", "previous_status", "new_status", "changed_by", "created_at")
    list_filter   = ("new_status",)
    readonly_fields = ("request", "previous_status", "new_status",
                       "changed_by", "notes", "created_at")

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False    