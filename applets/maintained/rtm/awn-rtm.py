#!/usr/bin/python
#
#       RTM Applet
#
#       Copyright (c) 2008 Andrew Starr-Bochicchio (andrewsomething) <a.starr.b@gmail.com>
#
#       This library is free software; you can redistribute it and/or
#       modify it under the terms of the GNU Lesser General Public
#       License as published by the Free Software Foundation; either
#       version 2 of the License, or (at your option) any later version.
#
#       This library is distributed in the hope that it will be useful,
#       but WITHOUT ANY WARRANTY; without even the implied warranty of
#       MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#       Lesser General Public License for more details.
#
#       You should have received a copy of the GNU Lesser General Public
#       License along with this library; if not, write to the
#       Free Software Foundation, Inc., 59 Temple Place - Suite 330,
#       Boston, MA 02111-1307, USA.
#
#
#  Thanks to ryancr the gtkmozembed bit from the Meebo Applet. 
#  And Malept for the work around for the gtkmozebed bug in Ubuntu.   
#  And Remember the Milk for such a great web app.
#  And of course NJPatel for Avant Window Navigator and the AWN Test Python Applet.
#
#
# TODO: Eventually use Remember The Milk's open API and ditch mozembed alltogether.
#
#


import sys, os
import shutil
import pygtk
import gtk
import webbrowser
import awn
import re

# workaround for weirdness with regards to Ubuntu + gtkmozembed
if os.path.exists('/etc/issue'):
    fp = open('/etc/issue')
    os_version = fp.read()
    fp.close()
    if re.search(r'7\.(?:04|10)', os_version): # feisty or gutsy
        os.putenv('LD_LIBRARY_PATH', '/usr/lib/firefox')
        os.putenv('MOZILLA_FIVE_HOME', '/usr/lib/firefox')

try:
        import gtkmozembed
except ImportError:
        print '       #####################################'
        print 'Gtkmozembed is needed to run the RTM-Applet, please install.'
        print ' * On Debian or Ubuntu based systems, install python-gnome2-extras'
        print ' * On Gentoo based systems, install dev-python/gnome-python-extras'
        print ' * On Fedora based systems, install gnome-python2-gtkmozembed'
        print ' * On SUSE based systems, install python-gnome-extras'
        print ' * On Mandriva based systems, install gnome-python-gtkmozembed'
        print 'See: http://wiki.awn-project.org/Awn_Extras:Dependency_Matrix'
        print '       #####################################'

# Add pop up if gtkmozembed isn't found
awn.check_dependencies(globals(), 'gtkmozembed')


class App (awn.AppletSimple):
  def __init__ (self, uid, orient, height):
    awn.AppletSimple.__init__ (self, uid, orient, height)
    self.icon = self.set_awn_icon('rtm', 'awn-rtm')
    self.title = awn.awn_title_get_default ()
    self.dialog = awn.AppletDialog (self)

    # set up mozilla profile
    self.mo  = gtkmozembed;
    self.pref_path = os.path.join(os.path.expanduser('~'), ".config/awn/applets/rtm")
    self.prefs = self.pref_path + "/profile/prefs.js"
    if os.path.exists(self.prefs) == True:
        self.mo.set_profile_path(self.pref_path, "profile")
    else:
        self.mo.set_profile_path(self.pref_path, "profile")
        shutil.copy(os.path.abspath(os.path.dirname(__file__)) + "/prefs.js", self.prefs)

    # set up gtkmozembed widget
    self.moz = self.mo.MozEmbed()
    pad = gtk.Alignment()
    pad.add(self.moz)
    self.moz.set_size_request(250, 350)
    self.moz.load_url('http://www.rememberthemilk.com/services/modules/googleig/')
    pad.show_all()
    self.dialog.add(pad)

    self.showing_dlog = False

    self.connect ("button-press-event", self.button_press)
    self.connect ("enter-notify-event", self.enter_notify)
    self.connect ("leave-notify-event", self.leave_notify)
    self.dialog.props.hide_on_unfocus = True



  def context_menu(self, widget, event):        # create context menu
    menu = self.create_default_menu()
    about_icon = gtk.ImageMenuItem(stock_id=gtk.STOCK_ABOUT)
    menu.append(about_icon)
    menu.show_all()
    menu.popup(None, None, None, event.button, event.get_time())
    about_icon.connect_object("activate",self.about,self)
    return True



  def button_press(self, widget, event):        # button press actions
    if event.button == 2:
      url = "http://www.rememberthemilk.com"
      webbrowser.open(url)
    elif event.button == 3:
      self.context_menu(widget, event)
    else:
      if event.button == 1:  
         if self.showing_dlog:
            self.dialog.hide()
         else:
            self.dialog.show_all()

      self.title.hide(self)
      self.showing_dlog = not self.showing_dlog


  def enter_notify (self, widget, event):        # cursor hover over
    self.title.show (self, "Remember The Milk")

  def leave_notify (self, widget, event):
    self.title.hide (self)

  def about(self, applet):                      # create gtk about dialog
    about_dialog = gtk.AboutDialog()
    about_dialog.set_logo(applet.icon)
    about_dialog.set_name("RTM Applet")
    about_dialog.set_version("0.2")
    about_dialog.set_copyright("Copyright 2008 LGPL")
    about_dialog.set_comments("RememberTheMilk is an on-line based prodcutivity application, and the RTM Applet brings it to your desktop. RTM Applet is not endorsed or certified by RememberTheMilk.")
    about_dialog.set_website("http://www.wiki.awn-project.org")
    about_dialog.connect("response", lambda d, r: d.destroy())
    about_dialog.show() 

if __name__ == "__main__":
  awn.init (sys.argv[1:])
  applet = App (awn.uid, awn.orient, awn.height)
  awn.embed_applet (applet)
  applet.show_all ()
  gtk.main ()
