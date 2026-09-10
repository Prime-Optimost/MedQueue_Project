# Generated migration for profile picture upload support

import django.db.models.deletion
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('base', '0004_emergencycontact_emergencyrequest_emergencystatuslog_and_more'),
    ]

    operations = [
        # Remove the old URLField
        migrations.RemoveField(
            model_name='user',
            name='profile_picture_url',
        ),
        # Add the new ImageField
        migrations.AddField(
            model_name='user',
            name='profile_picture',
            field=models.ImageField(
                blank=True,
                null=True,
                upload_to='profile_pictures/',
                help_text='User profile picture'
            ),
        ),
    ]
