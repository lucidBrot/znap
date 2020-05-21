```bash
znap -t tank/ds1/u18 -m COMMIT_MESSAGE
```

Creates a snapshot of the dataset `tank/ds1/u18` and stores `COMMIT_MESSAGE` in a file at `/opt/znap`.



```bash
znap log
```

Opens a text editor for that file.

### Why?
Because I really don't want to type the date command again and again.
And `znap` keeps track of commit messages in a file per dataset:

```
tank/ds1/u18@2005082034     swap partition instead of /swapfile.
							hibernate enabled but without "nomodeset" yet.
							Not yet tested.

tank/ds1/u18@2005091133 	Setup Telegram.
							Hibernation seems to be working perfectly.
							But they say nomodeset can cause performance hits.
							`systemctl suspend` seems to leave the screen on?

```
