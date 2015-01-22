;;; emacspeak-webspace.el --- Webspaces In Emacspeak
;;; $Id: emacspeak-webspace.el 8398 2013-08-26 01:52:29Z tv.raman.tv $
;;; $Author: tv.raman.tv $
;;; Description: WebSpace provides smart updates from the Web.
;;; Keywords: Emacspeak, Audio Desktop webspace
;;{{{ LCD Archive entry:

;;; LCD Archive Entry:
;;; emacspeak| T. V. Raman |raman@cs.cornell.edu
;;; A speech interface to Emacs |
;;; $Date: 2007-05-03 18:13:44 -0700 (Thu, 03 May 2007) $ |
;;; $Revision: 4532 $ |
;;; Location undetermined
;;;

;;}}}
;;{{{ Copyright:
;;;Copyright (C) 1995 -- 2011, T. V. Raman
;;; Copyright (c) 1994, 1995 by Digital Equipment Corporation.
;;; All Rights Reserved.
;;;
;;; This file is not part of GNU Emacs, but the same permissions apply.
;;;
;;; GNU Emacs is free software; you can redistribute it and/or modify
;;; it under the terms of the GNU General Public License as published by
;;; the Free Software Foundation; either version 2, or (at your option)
;;; any later version.
;;;
;;; GNU Emacs is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNWEBSPACE FOR A PARTICULAR PURPOSE. See the
;;; GNU General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with GNU Emacs; see the file COPYING. If not, write to
;;; the Free Software Foundation, 675 Mass Ave, Cambridge, MA 02139, USA.

;;}}}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;{{{ introduction

;;; Commentary:
;;; WEBSPACE == Smart Web Gadgets For The Emacspeak Desktop
;;; Code:
;;}}}
;;{{{ Required modules

(require 'cl)
(declaim (optimize (safety 0) (speed 3)))
(require 'emacspeak-preamble)
(require 'ring)
(require 'derived)
(require 'gfeeds)

(require 'gweb)
(require 'emacspeak-webutils)
;;}}}
;;{{{ WebSpace Mode:

;;; Define a derived-mode called WebSpace that is generally useful for hypetext display.

(define-derived-mode emacspeak-webspace-mode special-mode
  "Webspace Interaction"
  "Major mode for Webspace interaction.\n\n
\\{emacspeak-webspace-mode-map}")

(declaim (special emacspeak-webspace-mode-map))

(loop for k in 
      '(
        ("q" bury-buffer)
        ("<" beginning-of-buffer)
        (">" end-of-buffer)
        ("/" search-forward)
        ("?" search-backward)
        ("\t" emacspeak-webspace-next-link)
        ([S-tab] emacspeak-webspace-previous-link)
        ("f" emacspeak-webspace-next-link)
        ("b" emacspeak-webspace-previous-link)
        ("y" emacspeak-webspace-yank-link)
        ("A"emacspeak-webspace-atom-view)
        ("R" emacspeak-webspace-rss-view)
        ("F" emacspeak-webspace-feed-view)
        ("t" emacspeak-webspace-transcode)
        ("\C-m" emacspeak-webspace-open)
        ("." emacspeak-webspace-filter)
        ("n" next-line)
        ("p" previous-line)
        ("g" emacspeak-webspace-reader-refresh))
      do
      (emacspeak-keymap-update  emacspeak-webspace-mode-map k))

(defsubst emacspeak-webspace-act-on-link (action &rest args)
  "Apply action to link  under point."
  (let ((link (get-text-property (point) 'link)))
    (if link
        (apply action  link args)
      (message "No link under point."))))

;;;###autoload
(defun emacspeak-webspace-transcode ()
  "Transcode headline at point by following its link property."
  (interactive)
  (emacspeak-webspace-act-on-link 'emacspeak-webutils-transcode-this-url-via-google))

(defun emacspeak-webspace-atom-view ()
  "View Atom feed."
  (interactive)
  (emacspeak-webutils-autospeak)
  (emacspeak-webspace-act-on-link 'emacspeak-webutils-atom-display))

(defun emacspeak-webspace-rss-view ()
  "View RSS feed."
  (interactive)
  (emacspeak-webutils-autospeak)
  (emacspeak-webspace-act-on-link 'emacspeak-webutils-rss-display))

(defun emacspeak-webspace-feed-view ()
  "View  feed using gfeeds."
  (interactive)
  (emacspeak-webspace-act-on-link 'gfeeds-view))

;;;###autoload
(defun emacspeak-webspace-yank-link ()
  "Yank link under point into kill ring."
  (interactive)
  (let ((link (get-text-property (point) 'link)))
    (cond
     (link
      (kill-new link)
      (emacspeak-auditory-icon 'yank-object)
      (message link))
     (t (error "No link under point")))))

(defadvice gfeeds-view (around emacspeak pre act comp)
  "Automatically speak display."
  (when (ems-interactive-p )
    (emacspeak-webutils-autospeak))
  ad-do-it
  ad-return-value)

;;;###autoload
(defun emacspeak-webspace-open ()
  "Open headline at point by following its link property."
  (interactive)
  (emacspeak-webspace-act-on-link 'browse-url))

;;;###autoload
(defun emacspeak-webspace-filter ()
  "Open headline at point by following its link property and filter for content."
  (interactive)
  (let ((link (get-text-property (point) 'link)))
    (if link
        (emacspeak-we-xslt-filter
         emacspeak-we-recent-xpath-filter
         link 'speak)
      (message "No link under point."))))
;;;###autoload
(defun emacspeak-webspace-next-link()
  "Move to next link."
  (interactive)
  (goto-char
   (next-single-property-change
    (point) 'link nil (point-max)))
  (emacspeak-auditory-icon 'large-movement)
  (emacspeak-speak-line))

;;;###autoload
(defun emacspeak-webspace-previous-link()
  "Move to previous link."
  (interactive)
  (goto-char
   (previous-single-property-change
    (point) 'link nil (point-min)))
  (emacspeak-auditory-icon 'large-movement)
  (emacspeak-speak-line))

;;}}}
;;{{{ WebSpace Display:

;;;###autoload
(defun emacspeak-webspace-headlines-view ()
  "Display all cached headlines in a special interaction buffer."
  (interactive)
  (declare (special emacspeak-webspace-headlines))
  (let ((buffer (get-buffer-create "Headlines"))
        (inhibit-read-only t))
    (save-excursion
      (set-buffer buffer)
      (erase-buffer)
      (setq buffer-undo-list t)
      (mapc
       #'(lambda (r)
           (insert (format "%s\n" r)))
       (ring-elements
        (emacspeak-webspace-fs-titles emacspeak-webspace-headlines))))
    (switch-to-buffer buffer)
    (setq buffer-read-only t)
    (emacspeak-webspace-mode)
    (goto-char (point-min))
    (emacspeak-auditory-icon 'open-object)
    (emacspeak-speak-line)))

(defsubst emacspeak-webspace-display (infolet)
  "Displays specified infolet.
Infolets use the same structure as mode-line-format and header-line-format.
Generates auditory and visual display."
  (declare (special header-line-format))
  (setq header-line-format infolet)
  (dtk-speak (format-mode-line header-line-format))
  (emacspeak-auditory-icon 'progress))
;;;###autoload
(define-prefix-command 'emacspeak-webspace 'emacspeak-webspace-keymap)

(declaim (special emacspeak-webspace-keymap))

(loop for k in
      '(
        ("w" emacspeak-webspace-weather)
        ("h" emacspeak-webspace-headlines)
        ("r" emacspeak-webspace-reading-list)
        )
      do
      (define-key emacspeak-webspace-keymap (first k) (second k)))
(global-set-key [C-return] 'emacspeak-webspace-headlines-view)
;;}}}
;;{{{ Headlines:

(defcustom emacspeak-webspace-feeds nil
  "Collection of ATOM and RSS feeds."
  :type '(repeat
          (string :tag "URL"))
  :group  'emacspeak-webspace)

;;; Encapsulate collection feeds, headlines, timer, and  recently updated feed.-index

(defstruct emacspeak-webspace-fs
  feeds titles
  timer slow-timer index )

(defvar emacspeak-webspace-headlines nil
  "Feedstore  structure to use a continuously updating ticker.")

(defsubst emacspeak-webspace-headlines-fetch ( feed)
  "Add headlines from specified feed to our cache."
  (let ((last-update (get-text-property 0 'last-update feed))
        (titles  (emacspeak-webspace-fs-titles emacspeak-webspace-headlines)))
    (when (or (null last-update)
              (time-less-p '(0 1800 0)  ; 30 minutes 
                           (time-since last-update)))
      (put-text-property 0 1 'last-update (current-time) feed)
      (mapc
       #'(lambda (h) (ring-insert titles h ))
       (gfeeds-titles feed)))))

(defsubst emacspeak-webspace-fs-next (fs)
  "Return next feed and increment index for fs."
  (let ((feed-url (aref
                   (emacspeak-webspace-fs-feeds fs)
                   (emacspeak-webspace-fs-index fs))))
    (setf (emacspeak-webspace-fs-index fs)
          (% (1+ (emacspeak-webspace-fs-index fs))
             (length (emacspeak-webspace-fs-feeds fs))))
    feed-url))

(defun emacspeak-webspace-headlines-populate ()
  "populate fs with headlines from all feeds."
  (declare (special emacspeak-webspace-headlines))
  (dotimes (i (length (emacspeak-webspace-fs-feeds emacspeak-webspace-headlines)))
    (emacspeak-webspace-headlines-fetch (emacspeak-webspace-fs-next emacspeak-webspace-headlines))))

(defsubst emacspeak-webspace-headlines-refresh ()
  "Update headlines."
  (declare (special emacspeak-webspace-headlines))
  (with-local-quit
    (emacspeak-webspace-headlines-fetch
     (emacspeak-webspace-fs-next emacspeak-webspace-headlines)))
  (emacspeak-auditory-icon 'working)
  t)

(defun emacspeak-webspace-update-headlines ()
  "Setup  news updates.
Updated headlines found in emacspeak-webspace-headlines."
  (interactive)
  (declare (special emacspeak-webspace-headlines))
  (let ((timer nil)
        (slow-timer nil))
    (setq timer 
          (run-with-idle-timer
           60 t 'emacspeak-webspace-headlines-refresh))
    (setq slow-timer 
          (run-with-idle-timer
           3600
           t 'emacspeak-webspace-headlines-populate))
    (setf (emacspeak-webspace-fs-timer emacspeak-webspace-headlines) timer)
    (setf (emacspeak-webspace-fs-slow-timer emacspeak-webspace-headlines) slow-timer)))

(defun emacspeak-webspace-next-headline ()
  "Return next headline to display."
  (declare (special emacspeak-webspace-headlines))
  (let ((titles (emacspeak-webspace-fs-titles emacspeak-webspace-headlines)))
    (cond
     ((ring-empty-p titles)
      (emacspeak-webspace-headlines-refresh)
      "No News Is Good News")
     (t (let ((h (ring-remove titles 0)))
          (ring-insert-at-beginning titles h)
          h)))))

;;;###autoload
(defun emacspeak-webspace-headlines ()
  "Speak current news headline."
  (interactive)
  (declare (special emacspeak-webspace-headlines))
  (unless emacspeak-webspace-headlines
    (setq emacspeak-webspace-headlines
          (make-emacspeak-webspace-fs
           :feeds (apply 'vector emacspeak-webspace-feeds)
           :titles (make-ring (* 10 (length emacspeak-webspace-feeds)))
           :index 0)))
  (unless (emacspeak-webspace-fs-timer emacspeak-webspace-headlines)
    (call-interactively 'emacspeak-webspace-update-headlines))
  (emacspeak-webspace-display '((:eval (emacspeak-webspace-next-headline)))))

;;}}}
;;{{{ Weather:

(defvar emacspeak-webspace-weather-url-template
  "http://www.wunderground.com/auto/rss_full/%s.xml"
  "URL template for weather feed.")

(defun emacspeak-webspace-weather-conditions ()
  "Return weather conditions for `emacspeak-url-template-weather-city-state'."
  (declare (special emacspeak-url-template-weather-city-state
                    emacspeak-webspace-weather-url-template))
  (when (and emacspeak-webspace-weather-url-template
             emacspeak-url-template-weather-city-state)
    (with-local-quit
      (format "%s at %s"
              (first
               (gfeeds-titles
                (format emacspeak-webspace-weather-url-template
                        emacspeak-url-template-weather-city-state)))
              emacspeak-url-template-weather-city-state))))

(defvar emacspeak-webspace-current-weather nil
  "Holds cached value of current weather conditions.")

(defvar emacspeak-webspace-weather-timer nil
  "Timer holding our weather update timer.")
(defun emacspeak-webspace-weather-get ()
  "Get weather."
  (declare (special emacspeak-webspace-current-weather))
  (setq emacspeak-webspace-current-weather
        (emacspeak-webspace-weather-conditions)))

(defun emacspeak-webspace-update-weather ()
  "Setup periodic weather updates.
Updated weather is found in `emacspeak-webspace-current-weather'."
  (interactive)
  (declare (special emacspeak-webspace-weather-timer))
  (unless emacspeak-url-template-weather-city-state
    (error
     "First set option emacspeak-url-template-weather-city-state to your city/state."))
  (emacspeak-webspace-weather-get)
  (setq emacspeak-webspace-weather-timer
        (run-with-idle-timer 600 'repeat
                             'emacspeak-webspace-weather-get )))

;;;###autoload
(defun emacspeak-webspace-weather ()
  "Speak current weather."
  (interactive)
  (declare (special emacspeak-webspace-current-weather
                    emacspeak-webspace-weather-timer))
  (unless emacspeak-webspace-weather-timer
    (call-interactively 'emacspeak-webspace-update-weather))
  (emacspeak-webspace-display 'emacspeak-webspace-current-weather))

;;}}}
;;{{{ Google Reader In Webspace:

(defvar emacspeak-webspace-reader-buffer "Reader"
  "Name of Reader buffer.")

(defun emacspeak-webspace-reader-create ()
  "Prepare Reader buffer."
  (declare (special emacspeak-webspace-reader-buffer
                    emacspeak-webspace-reader-feed-list))
  (browse-url (format "file:%s"emacspeak-webspace-reader-feed-list)))

;;;###autoload
(defcustom emacspeak-webspace-reader-feed-list
  (expand-file-name  "reader.html" "~/.emacspeak")
  "HTML file containing list of feeds.")

;;;###autoload 
(defun emacspeak-webspace-reader (&optional refresh)
  "Display Google Reader Feed list in a WebSpace buffer.
Optional interactive prefix arg forces a refresh."
  (interactive "P")
  (declare (special emacspeak-webspace-reader-buffer))
  (when (or refresh
            (not (buffer-live-p  (get-buffer emacspeak-webspace-reader-buffer))))
    (emacspeak-webspace-reader-create))
  (switch-to-buffer emacspeak-webspace-reader-buffer)
  (goto-char (point-min))
  (emacspeak-speak-mode-line)
  (emacspeak-auditory-icon 'open-object))

;;;###autoload
(defvar emacspeak-webspace-reading-list-buffer
  "Reading List"
  "Buffer where we accumulate reading list headlines.")

(defconst emacspeak-webspace-reading-list-max-size 1800
  "How many headlines we keep around.")

;;;###autoload
(defun emacspeak-webspace-reading-list-view ()
  "Switch to reading list view, creating it if needed."
  (interactive)
  (declare (special emacspeak-webspace-reading-list-buffer))
  (unless (buffer-live-p (get-buffer emacspeak-webspace-reading-list-buffer))
    (emacspeak-webspace-reading-list-accumulate))
  (emacspeak-auditory-icon 'select-object)
  (switch-to-buffer emacspeak-webspace-reading-list-buffer)
  (emacspeak-speak-mode-line))

;;;###autoload
(defun emacspeak-webspace-reader-refresh ()
  "Refresh Reader."
  (interactive )
  (emacspeak-webspace-reader 'refresh)  (emacspeak-speak-mode-line)
  (emacspeak-auditory-icon 'open-object))

;;;###autoload

(defun emacspeak-webspace-reading-list-get-some-title ()
  "Returns a title chosen at random.
Leaves point on the title returned in the reading list buffer."
  (declare (special emacspeak-webspace-reading-list-buffer))
  (unless (buffer-live-p (get-buffer emacspeak-webspace-reading-list-buffer))
    (emacspeak-webspace-reading-list-accumulate))
  (with-current-buffer (get-buffer emacspeak-webspace-reading-list-buffer)
    (let ((choice
           (random  (count-lines (point-min) (point-max)))))
      (goto-char (point-min))
      (forward-line (1- choice))
      (buffer-substring (line-beginning-position)
                        (line-end-position)))))

(defvar emacspeak-webspace-reading-list-timer nil
  "Timer used to  regularly update river of news.")

;;;###autoload
(defun emacspeak-webspace-reading-list ()
  "Set up scrolling reading list in header."
  (interactive)
  (declare (special emacspeak-webspace-reading-list-buffer
                    emacspeak-webspace-reading-list-timer))
  (unless (buffer-live-p (get-buffer emacspeak-webspace-reading-list-buffer))
    (emacspeak-webspace-reading-list-accumulate))
  (unless emacspeak-webspace-reading-list-timer
    (setq emacspeak-webspace-reading-list-timer
          (run-with-timer 1800 1800   'emacspeak-webspace-reading-list-accumulate)))
  (emacspeak-webspace-display '((:eval (emacspeak-webspace-reading-list-get-some-title)))))

;;}}}
;;{{{ Google Search in WebSpace:

(defun emacspeak-webspace-google-save-results(results)
  "Save results in a WebSpace mode buffer for later use."
  (declare (special  gweb-history))
  (let ((buffer
         (get-buffer-create
          (format "Search %s" (first gweb-history))))
        (inhibit-read-only t)
        (start nil))
    (save-excursion
      (set-buffer buffer)
      (erase-buffer)
      (setq buffer-undo-list t)
      (insert (format "Search Results For %s\n\n"
                      (first gweb-history)))
      (center-line)
      (loop for r across results
            and i from 1
            do
            (setq start (point))
            (insert
             (format
              "%d. %s\n%s"
              i
              (g-json-get 'titleNoFormatting r)
              (shell-command-to-string
               (format
                "echo '%s' | lynx -dump -stdin 2>/dev/null"
                (g-json-get 'content r)))))
            (put-text-property
             start (point)
             'link (g-json-get 'url r)))
      (emacspeak-webspace-mode)
      (setq buffer-read-only t)
      (goto-char (point-min)))
    (display-buffer buffer)
    (emacspeak-auditory-icon 'open-object)))

;;;###autoload
(defun emacspeak-webspace-google ()
  "Display Google Search in a WebSpace buffer."
  (interactive)
  (let ((gweb-search-results-handler 'emacspeak-webspace-google-save-results))
    (call-interactively 'gweb-google-at-point)))

;;}}}
(provide 'emacspeak-webspace)
;;{{{ end of file

;;; local variables:
;;; folded-file: t
;;; byte-compile-dynamic: nil
;;; end:

;;}}}
