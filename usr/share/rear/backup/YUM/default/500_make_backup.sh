#
# backup/YUM/default/500_make_backup.sh
# 500_make_backup.sh is the default script name to make a backup
# see backup/readme
#

# For BACKUP=YUM the RPM data got stored into the
# ReaR recovery system via prep/YUM/default/400_prep_rpm.sh
# When backup/YUM/default/500_make_backup.sh runs
# the ReaR recovery system is already made
# (its recovery/rescue system initramfs/initrd is already created)
# so that at this state nothing can be stored into the recovery system.
# At this state an additional normal file based backup can be made
# in particular to backup all those files that do not belong to an installed YUM package
# (e.g. files in /home/ directories or third-party software in /opt/) or files
# that belong to a YUM package but are changed (i.e. where "rpm -V" reports differences)
# (e.g. config files like /etc/default/grub).

if ! is_true "$YUM_BACKUP_FILES" ; then
	LogPrint "Not backing up system files (YUM_BACKUP_FILES=$YUM_BACKUP_FILES)"
	return
fi
LogPrint "Backing up system files (YUM_BACKUP_FILES=$YUM_BACKUP_FILES)"

# Try to care about possible errors
# see https://github.com/rear/rear/wiki/Coding-Style
set -e -u -o pipefail

# Store the files generated here in the same directory as the backup archive file
# so they are available during recovery
local yum_backup_dir=$(dirname "$backuparchive")
test -d $yum_backup_dir || mkdir $verbose -p -m 755 $yum_backup_dir

# Catalog all files provided by RPM packages
for file in $(rpm -Vva | grep '^\.\.\.\.\.\.\.\.\.' | grep -v '^...........c' | cut -c 14-); do [ -f $file ] && echo $file; done > $yum_backup_dir/rpm_provided_files.dat

# Gather RPM verification data
rpm -Va > $yum_backup_dir/rpm_verification.dat

# Use the RPM verification data to catalog RPM-provided files which have been modified...
grep -v ^missing $yum_backup_dir/rpm_verification.dat | cut -c 14- > $yum_backup_dir/rpm_modified_files.dat
# ...or are missing
grep ^missing $yum_backup_dir/rpm_verification.dat | cut -c 14- > $yum_backup_dir/rpm_missing_files.dat

# Create an exclusion file which is a list of the RPM-provided files which have NOT been modified
grep -Fvxf $yum_backup_dir/rpm_modified_files.dat $yum_backup_dir/rpm_provided_files.dat > $yum_backup_dir/rpm_backup_exclude_files.dat

# Generate the actual backup archive
tar --preserve-permissions --same-owner --warning=no-xdev --sparse --block-number --totals --no-wildcards-match-slash --one-file-system --ignore-failed-read --anchored --selinux --gzip -C / -c -f $backuparchive --exclude-from=$yum_backup_dir/rpm_backup_exclude_files.dat -X $TMP_DIR/backup-exclude.txt $(cat $TMP_DIR/backup-include.txt) $RUNTIME_LOGFILE

# Restore the ReaR default bash flags and options (see usr/sbin/rear):
apply_bash_flags_and_options_commands "$DEFAULT_BASH_FLAGS_AND_OPTIONS_COMMANDS"
