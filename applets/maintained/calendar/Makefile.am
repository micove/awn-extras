APPLET_NAME = calendar
APPLET_MAIN_FILE = clockcal.py
include $(top_srcdir)/Makefile.python-applet
include $(top_srcdir)/Makefile.schemas

dist_applet_DATA =	\
	calendarlogin.py\
	calendarprefs.py\
	calthread.py	\
	evocal.py	\
	googlecal.py	\
	icscal.py	\
	owacal.py	\
	sevensegled.py	\
	$(NULL)

imagesdir = $(applet_datadir)/images
dist_images_DATA = $(wildcard images/*.png)
