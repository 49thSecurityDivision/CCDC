# CCDC Scripts

- linux-scripts/ -- contains useful linux scripts

## Linux: Showing differences

Use diff to show the difference of two files:

    diff -u /tmp/file1 /tmp/file2

Diff two folders and show the differences

    diff -qr /tmp/dir1 /tmp/dir2# Package manager tricks

## Linux: Package Managers
### RPM

List all installed RPM packages

    rpm -qa


List all files that belong to package "mypackage"

    rpm -ql mypackage

Show which package that a file belongs to

    rpm -qf /path/to/file


### dpkg

List all installed packages

    dpkg -l

List all files the belong to the package "mypackage"

    dpkg -L mypackage

Show which package that a file belongs to

    dpkg --search /path/to/file

or

    dpkg -S /path/to/file


## Linux:  Shell tricks

List the 5th column from myfile

   cat myfile | awk '{print $5}'

Show the top 20 occurences of IP addresses (first column) from an Apache common log file. First column is the count, second is the IP address.

    cat mylogfile | awk '{print $1}' | sort | uniq -c | sort -n | tail -n20# Integrity checking

### Checksums

This stuff substitutes for a poor-man's aide.

Generate SHA1 checksums for all files in current folder and all subfolders

    find . -type f -print0 | xargs -0 sha1sum > /tmp/checksums

Verify the checksums generated above.

    sha1sum -c /tmp/checksums

Verify the checksums of dpkg-managed files on an Ubuntu/Debian system. Only print if files fail the checksum.

    find  /var/lib/dpkg/info/ -name "*.md5sums" | xargs md5sum -c  | grep -v ': OK$'

Verify permissions and checksums of all RPM-managed files on a RPM-based distro. This only prints things that were altered.

    rpm -Va

### Permissions

List the attributes in CSV format of files in the current folder and subfolders
(user.group, mode, size, filetype,modification time,filename):

    find . | xargs -n1 stat  --format="%U.%G,en%a,%s,'%F',%i,'%y','%n'" > /tmp/perms
