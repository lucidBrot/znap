### snapshot with commit message
```bash
znap -t tank/ds1/u18 -m COMMIT_MESSAGE
```

Creates a snapshot of the dataset `tank/ds1/u18` and stores `COMMIT_MESSAGE` in a file at `/opt/znap` (modify the script to your liking).
Be aware that the commit messages are only in one file and hence will not automatically be backed up. But they are written before the snapshot is taken, so if you snapshot the dataset where the logfile is stored, it will save the new commit message as well.

### log

```bash
znap log
```

Outputs all commit messages formatted like this:

```bash
$ ./znap.sh log
tank/ds1/u18@2005082034              swap partition instead of /swapfile.
                                     hibernate enabled but without nomodeset yet.
                                     Not yet tested.
tank/ds1/u18@2005091133@2005221155   Setup Telegram.
                                     Hibernation seems to be working perfectly.
                                     But they say nomodeset can cause performance hits.
                                     `systemctl suspend` seems to leave the screen on?

```

### filtered log

You can apply regex search to the first line of every entry. That includes both columns.

```bash
$ ./znap.sh log u18
tank/ds1/u18@2005082034              swap partition instead of /swapfile.
                                     hibernate enabled but without nomodeset yet.
                                     Not yet tested.
tank/ds1/u18@2005091133@2005221155   Setup Telegram.
                                     Hibernation seems to be working perfectly.
                                     But they say nomodeset can cause performance hits.
                                     `systemctl suspend` seems to leave the screen on?

$ ./znap.sh log Telegram
tank/ds1/u18@2005091133@2005221155   Setup Telegram.
                                     Hibernation seems to be working perfectly.
                                     But they say nomodeset can cause performance hits.
      
$ ./znap.sh log @200508
tank/ds1/u18@2005082034              swap partition instead of /swapfile.
                                     hibernate enabled but without nomodeset yet.
                                     Not yet tested.

```

To search for only `tank` but not for `tank/ds1`, you would for example perform a `znap log tank@`.

### Why?

Because I really don't want to type the date command again and again.
And `znap` keeps track of commit messages in a file. I sync that file to my desktop to keep track of the changes I made on my laptop.