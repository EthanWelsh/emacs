;;; emacspeak-speak.el --- Implements Emacspeak's core speech services
;;; $Id: emacspeak-speak.el 8578 2013-11-25 17:59:49Z tv.raman.tv $
;;; $Author: tv.raman.tv $
;;; Description:  Contains the functions for speaking various chunks of text
;;; Keywords: Emacspeak,  Spoken Output
;;{{{  LCD Archive entry:

;;; LCD Archive Entry:
;;; emacspeak| T. V. Raman |raman@cs.cornell.edu
;;; A speech interface to Emacs |
;;; $Date: 2008-08-18 16:25:05 -0700 (Mon, 18 Aug 2008) $ |
;;;  $Revision: 4552 $ |
;;; Location undetermined
;;;

;;}}}
;;{{{  Copyright:
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
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with GNU Emacs; see the file COPYING.  If not, write to
;;; the Free Software Foundation, 675 Mass Ave, Cambridge, MA 02139, USA.

;;}}}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;{{{  Introduction:

;;; Commentary:

;;; This module defines the core speech services used by emacspeak.
;;; It depends on the speech server interface modules
;;; It protects other parts of emacspeak
;;; from becoming dependent on the speech server modules

;;; Code:

;;}}}
;;{{{  Required modules

(require 'cl)
(declaim  (optimize  (safety 0) (speed 3)))
(require 'custom)
(require 'time-date)
(require 'voice-setup)
(require 'thingatpt)
(require 'dtk-speak)
(require 'dtk-unicode)
(eval-when-compile
  (require 'shell)
  )

;;}}}
;;{{{ forward declarations:
(defvar emacspeak-codename)
(defvar emacspeak-last-message)
(defvar emacspeak-resource-directory)
(defvar emacspeak-sounds-directory)
(defvar emacspeak-version)
(defvar semantic--buffer-cache)
(defvar voice-animate)
(defvar voice-annotate)
(defvar voice-bolden)
(defvar voice-bolden-medium)
(defvar voice-indent)
(defvar voice-punctuations-some)
(defvar voice-smoothen)

(declare-function operate-on-rectangle(start end coerse-tabs))

;;}}}
;;{{{  custom group
(defgroup emacspeak-speak nil
  "Basic speech output commands."
  :group 'emacspeak)

;;}}}
;;{{{ same-line-p

(defsubst ems-same-line-p (orig current)
  "Check if current is in the same line as orig."
  (save-excursion
    (goto-char orig)
    (< current (line-end-position))))

;;}}}
;;{{{ Shell Command Helper:

;;; Emacspeak silences messages from shell-command when called non-interactively.
;;; This replacement is used within Emacspeak to invoke commands
;;; whose output we want to hear.

(defsubst  emacspeak-shell-command (command)
  "Run shell command and speak its output."
  (let ((emacspeak-speak-messages nil)
        (output (get-buffer-create "*Emacspeak Shell Command*")))
    (save-current-buffer
      (set-buffer output)
      (erase-buffer)
      (shell-command
       command
       output)
      (emacspeak-auditory-icon 'open-object)
      (dtk-speak (buffer-string)))))

;;}}}
;;{{{ Completion helper:

(defsubst emacspeak-speak-completions-if-available ()
  "Speak completions if available."
  (interactive)
  (let ((completions (get-buffer "*Completions*")))
    (cond
     ((and completions
           (window-live-p (get-buffer-window completions )))
      (save-current-buffer
        (set-buffer completions )
        (dtk-chunk-on-white-space-and-punctuations)
        (next-completion 1)
        (tts-with-punctuations 'all
                               (dtk-speak
                                (buffer-substring (point) (point-max))))))
     (t (emacspeak-speak-line)))))

;;}}}
;;{{{  Macros

;;; Save read-only and modification state, perform some actions and
;;; restore state

(defmacro ems-set-personality-temporarily (start end value &rest body)
  "Temporarily set personality.
Argument START   specifies the start of the region to operate on.
Argument END specifies the end of the region.
Argument VALUE is the personality to set temporarily
Argument BODY specifies forms to execute."
  `(let ((saved-personality (get-text-property ,start 'personality)))
     (with-silent-modifications
       (unwind-protect
           (progn
             (put-text-property
              (max (point-min) ,start)
              (min (point-max) ,end)
              'personality ,value)
             ,@body)
         (put-text-property
          (max (point-min) ,start)
          (min (point-max)  ,end) 'personality saved-personality)))))         

(defmacro ems-with-errors-silenced  (&rest body)
  "Evaluate body  after temporarily silencing auditory error feedback."
  `(progn
     (let ((emacspeak-speak-errors nil))
       ,@body)))

;;}}}
;;{{{ getting and speaking text ranges

(defsubst emacspeak-speak-get-text-range (property)
  "Return text range  around  at point and having the same value as  specified by argument PROPERTY."
  (buffer-substring
   (previous-single-property-change (point)
                                    property nil (point-min))
   (next-single-property-change
    (point) property nil (point-max))))

(defun emacspeak-speak-text-range (property)
  "Speak text range identified by this PROPERTY."
  (dtk-speak (emacspeak-speak-get-text-range property)))

;;}}}
;;{{{  Apply audio annotations

(defun emacspeak-audio-annotate-paragraphs ()
  "Set property auditory-icon at front of all paragraphs."
  (interactive )
  (save-excursion
    (goto-char (point-max))
    (with-silent-modifications
      (let ((sound-cue 'paragraph))
        (while (not (bobp))
          (backward-paragraph)
          (put-text-property  (point)
                              (+ 2    (point ))
                              'auditory-icon sound-cue ))))))

(defcustom  emacspeak-speak-paragraph-personality voice-animate
  "*Personality used to mark start of paragraph."
  :group 'emacspeak-speak
  :type 'symbol)

(defvar emacspeak-speak-voice-annotated-paragraphs nil
  "Records if paragraphs in this buffer have been voice
  annotated.")

(make-variable-buffer-local 'emacspeak-speak-voice-annotated-paragraphs)

(defsubst emacspeak-speak-voice-annotate-paragraphs ()
  "Locate paragraphs and voice annotate the first word.
Here, paragraph is taken to mean a chunk of text preceded by a blank line.
Useful to do this before you listen to an entire buffer."
  (interactive)
  (declare (special emacspeak-speak-paragraph-personality
                    emacspeak-speak-voice-annotated-paragraphs))
  (when emacspeak-speak-paragraph-personality
    (save-excursion
      (goto-char (point-min))
      (condition-case nil
          (let ((start nil)
                (blank-line "\n[ \t\n\r]*\n")
                (inhibit-point-motion-hooks t)
                (deactivate-mark nil))
            (with-silent-modifications
              (while (re-search-forward blank-line nil t)
                (skip-syntax-forward " ")
                (setq start (point))
                (unless (get-text-property start 'personality)
                  (skip-syntax-forward "^ ")
                  (put-text-property start (point)
                                     'personality
                                     emacspeak-speak-paragraph-personality)))))
        (error nil))
      (setq emacspeak-speak-voice-annotated-paragraphs t))))

;;}}}
;;{{{  sync emacspeak and TTS:

(defalias 'emacspeak-dtk-sync 'dtk-interp-sync)

;;}}}
;;{{{ helper function --decode ISO date-time used in ical:

(defvar emacspeak-speak-iso-datetime-pattern
  "[0-9]\\{8\\}\\(T[0-9]\\{6\\}\\)Z?"
  "Regexp pattern that matches ISO date-time.")

(defsubst emacspeak-speak-decode-iso-datetime (iso)
  "Return a speakable string description."
  (declare (special emacspeak-speak-time-format-string))
  (let ((year  (read (substring iso 0 4)))
        (month (read (substring iso 4 6)))
        (day   (read (substring iso 6 8)))
        (hour 0)
        (minute 0)
        (second 0))
    (when (> (length iso) 12) ;; hour/minute
      (setq hour (read (substring iso 9 11)))
      (setq minute (read (substring iso 11 13))))
    (when (> (length iso) 14) ;; seconds
      (setq second (read (substring iso 13 15))))
    (when (and (> (length iso) 15) ;; utc specifier
               (char-equal ?Z (aref iso 15)))
      (setq second (+ (car (current-time-zone
                            (encode-time second minute hour day month
                                         year))) second)))
    ;; create the decoded date-time
    (condition-case nil
        (format-time-string emacspeak-speak-time-format-string
                            (encode-time second minute hour day month
                                         year))
      (error iso))))

;;}}}
;;{{{ helper function --decode rfc 3339 date-time

(defvar emacspeak-speak-rfc-3339-datetime-pattern
  "[0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\}T[0-9]\\{2\\}:[0-9]\\{2\\}:[0-9]\\{2\\}\\(\\.[0-9]\\{3\\}\\)?\\([zZ]\\|\\([+-][0-9]\\{2\\}:[0-9]\\{2\\}\\)\\)"
  "Regexp pattern that matches RFC 3339 date-time.")

(defsubst ems-speak-rfc-3339-tz-offset (rfc-3339)
  "Return offset in seconds from UTC given an RFC-3339 time.
  Timezone spec is of the form -08:00 or +05:30 or [zZ] for UTC.
Value returned is compatible with `encode-time'."
  (cond
   ((string-match "[zZ]" (substring rfc-3339 -1))
    t)
   (t                                ;compute positive/negative offset
                                        ;in seconds
    (let ((fields
           (mapcar
            'read
            (split-string (substring rfc-3339 -5) ":"))))
      (*
       (if (string-match "-" (substring rfc-3339 -6))
           -60
         60)
       (+ (* 60 (first fields))
          (second fields)))))))

(defsubst emacspeak-speak-decode-rfc-3339-datetime (rfc-3339)
  "Return a speakable string description."
  (declare (special emacspeak-speak-time-format-string))
  (let ((year  (read (substring rfc-3339 0 4)))
        (month (read (substring rfc-3339 5 7)))
        (day   (read (substring rfc-3339 8 10)))
        (hour (read (substring rfc-3339 11 13)))
        (minute (read (substring rfc-3339 14 16)))
        (second (read (substring rfc-3339 17 19)))
        (tz (ems-speak-rfc-3339-tz-offset rfc-3339)))
    ;; create the decoded date-time
    (condition-case nil
        (format-time-string emacspeak-speak-time-format-string
                            (encode-time second minute hour day month
                                         year tz))
      (error rfc-3339))))

;;}}}
;;{{{  url link pattern:

;;;###autoload
(defcustom emacspeak-speak-embedded-url-pattern
  "<http:.*>"
  "Pattern to recognize embedded URLs."
  :type 'string
  :group 'emacspeak-speak)

;;}}}
;;{{{  Actions

;;; Setting value of property 'emacspeak-action to a list
;;; of the form (before | after function)
;;; function to be executed before or after the unit of text at that
;;; point is spoken.

(defvar emacspeak-action-mode nil
  "Determines if action mode is active.
Non-nil value means that any function that is set as the
value of property action is executed when the text at that
point is spoken."

  )

(make-variable-buffer-local 'emacspeak-action-mode)

;;; Record in the mode line
(or (assq 'emacspeak-action-mode minor-mode-alist)
    (setq minor-mode-alist
          (append minor-mode-alist
                  '((emacspeak-action-mode " Action")))))

;;; Return the appropriate action hook variable that defines actions
;;; for this mode.

(defsubst  emacspeak-action-get-action-hook (mode)
  "Retrieve action hook.
Argument MODE defines action mode."
  (intern (format "emacspeak-%s-actions-hook" mode )))

;;; Execute action at point
(defsubst emacspeak-handle-action-at-point ()
  "Execute action specified at point."
  (declare (special emacspeak-action-mode ))
  (let ((action-spec (get-text-property (point) 'emacspeak-action )))
    (when (and emacspeak-action-mode action-spec )
      (condition-case nil
          (funcall  action-spec )
        (error (message "Invalid actionat %s" (point )))))))

(ems-generate-switcher 'emacspeak-toggle-action-mode
                       'emacspeak-action-mode
                       "Toggle state of  Emacspeak  action mode.
Interactive PREFIX arg means toggle  the global default value, and then set the
current local  value to the result.")

;;}}}
;;{{{  line, Word and Character echo

;;;###autoload
(defcustom emacspeak-line-echo nil
  "If t, then emacspeak echoes lines as you type.
You can use \\[emacspeak-toggle-line-echo] to set this
option."
  :group 'emacspeak-speak
  :type 'boolean)

(ems-generate-switcher 'emacspeak-toggle-line-echo
                       'emacspeak-line-echo
                       "Toggle state of  Emacspeak  line echo.
Interactive PREFIX arg means toggle  the global default value, and then set the
current local  value to the result.")
;;;###autoload
(defcustom emacspeak-word-echo t
  "If t, then emacspeak echoes words as you type.
You can use \\[emacspeak-toggle-word-echo] to toggle this
option."
  :group 'emacspeak-speak
  :type 'boolean)

(ems-generate-switcher ' emacspeak-toggle-word-echo
                         'emacspeak-word-echo
                         "Toggle state of  Emacspeak  word echo.
Interactive PREFIX arg means toggle  the global default value, and then set the
current local  value to the result.")
;;;###autoload
(defcustom emacspeak-character-echo t
  "If t, then emacspeak echoes characters  as you type.
You can
use \\[emacspeak-toggle-character-echo] to toggle this
setting."
  :group 'emacspeak-speak
  :type 'boolean)

(ems-generate-switcher ' emacspeak-toggle-character-echo
                         'emacspeak-character-echo
                         "Toggle state of  Emacspeak  character echo.
Interactive PREFIX arg means toggle  the global default value, and then set the
current local  value to the result.")

;;}}}
;;{{{ Showing the point:

(defvar emacspeak-show-point nil
  " If T, then command  `emacspeak-speak-line' indicates position of point by an
aural highlight.  You can use
command `emacspeak-toggle-show-point' bound to
\\[emacspeak-toggle-show-point] to toggle this setting.")

(ems-generate-switcher ' emacspeak-toggle-show-point
                         'emacspeak-show-point
                         "Toggle state of  Emacspeak-show-point.
Interactive PREFIX arg means toggle  the global default value, and then set the
current local  value to the result.")

;;}}}
;;{{{ compute percentage into the buffer:
;;{{{ simple percentage getter

(defsubst emacspeak-get-current-percentage-into-buffer ()
  "Return percentage of position into current buffer."
  (let* ((pos (point))
         (total (buffer-size))
         (percent (if (> total 50000)
                      ;; Avoid overflow from multiplying by 100!
                      (/ (+ (/ total 200) (1- pos)) (max (/ total 100) 1))
                    (/ (+ (/ total 2) (* 100 (1- pos))) (max total 1)))))
    percent))

(defsubst emacspeak-get-current-percentage-verbously ()
  "Return percentage of position into current buffer as a string."
  (let ((percent (emacspeak-get-current-percentage-into-buffer)))
    (cond
     ((= 0 percent) " top ")
     ((= 100 percent) " bottom ")
     (t (format " %d%% " percent)))))

;;}}}

;;}}}
;;{{{  indentation:

(defcustom emacspeak-audio-indentation nil
  "Option indicating if line indentation is cued.
If non-nil , then speaking a line indicates its indentation.
You can use  command `emacspeak-toggle-audio-indentation' bound
to \\[emacspeak-toggle-audio-indentation] to toggle this
setting.."
  :group 'emacspeak-speak
  :type 'boolean)

(make-variable-buffer-local 'emacspeak-audio-indentation)

;;; Indicate indentation.
;;; Argument indent   indicates number of columns to indent.

(defsubst emacspeak-indent (indent)
  "Produce tone indent."
  (when (> indent 1 )
    (let ((duration (+ 50 (* 20  indent )))
          (dtk-stop-immediately nil))
      (dtk-tone  250 duration))))

(defvar emacspeak-audio-indentation-methods
  '(("speak" . "speak")
    ("tone" . "tone"))
  "Possible methods of indicating indentation.")

(defcustom emacspeak-audio-indentation-method   'speak
  "*Current technique used to cue indentation.  Default is
`speak'.  You can specify `tone' for producing a beep
indicating the indentation.  Automatically becomes local in
any buffer where it is set."
  :group 'emacspeak-speak
  :type '(choice
          (const :tag "Ignore" nil)
          (const :tag "speak" speak)
          (const :tag "tone" tone)))

(make-variable-buffer-local
 'emacspeak-audio-indentation-method)

(ems-generate-switcher ' emacspeak-toggle-audio-indentation
                         'emacspeak-audio-indentation
                         "Toggle state of  Emacspeak  audio indentation.
Interactive PREFIX arg means toggle  the global default value, and then set the
current local  value to the result.
Specifying the method of indentation as `tones'
results in the Dectalk producing a tone whose length is a function of the
line's indentation.  Specifying `speak'
results in the number of initial spaces being spoken.")

;;}}}
;;{{{ filtering columns

(defcustom emacspeak-speak-line-column-filter nil
  "*List that specifies columns to be filtered.
The list when set holds pairs of start-col.end-col pairs
that specifies the columns that should not be spoken.
Each column contains a single character --this is inspired
by cut -c on UNIX."
  :group 'emacspeak-speak
  :type '(choice
          (const :tag "None" nil)
          (repeat :tag "Filter Specification"
                  (list
                   (integer :tag "Start Column")
                   (integer :tag "End Column")))))

(defvar emacspeak-speak-filter-table (make-hash-table)
  "Hash table holding persistent filters.")

(make-variable-buffer-local 'emacspeak-speak-line-column-filter)

(defcustom emacspeak-speak-line-invert-filter nil
  "Non-nil means the sense of `filter' is inverted when filtering
columns in a line --see
command emacspeak-speak-line-set-column-filter."
  :type 'boolean
  :group 'emacspeak-speak)

(make-variable-buffer-local 'emacspeak-speak-line-invert-filter)

(ems-generate-switcher '
 emacspeak-toggle-speak-line-invert-filter
 'emacspeak-speak-line-invert-filter
 "Toggle state of   how column filter is interpreted.
Interactive PREFIX arg means toggle  the global default value, and then set the
current local  value to the result.")

(defsubst emacspeak-speak-line-apply-column-filter (line &optional invert-filter)
  (declare (special emacspeak-speak-line-column-filter))
  (let ((filter emacspeak-speak-line-column-filter)
        (l  (length line))
        (pair nil)
        (personality (if invert-filter nil
                       'inaudible)))
    (with-silent-modifications
      (when invert-filter
        (put-text-property  0   l
                            'personality 'inaudible line))
      (while filter
        (setq pair (pop filter))
        (when (and (<= (first pair) l)
                   (<= (second pair) l))
          (put-text-property (first pair)
                             (second pair)
                             'personality personality
                             line))))
    line))

(defsubst emacspeak-speak-persist-filter-entry (k v)
  (insert
   (format
    "(cl-puthash
(intern \"%s\")
'%s
emacspeak-speak-filter-table)\n" k v )))

(defcustom emacspeak-speak-filter-persistent-store
  (expand-file-name ".filters"
                    emacspeak-resource-directory)
  "File where emacspeak filters are persisted."
  :type 'file
  :group 'emacspeak-speak)

(defvar emacspeak-speak-filters-loaded-p nil
  "Records if we    have loaded filters in this session.")

(defun emacspeak-speak-lookup-persistent-filter (key)
  "Lookup a filter setting we may have persisted."
  (declare (special emacspeak-speak-filter-table))
  (gethash  (intern key) emacspeak-speak-filter-table))

(defun emacspeak-speak-set-persistent-filter (key value)
  "Persist filter setting for future use."
  (declare (special emacspeak-speak-filter-table))
  (setf (gethash  (intern key) emacspeak-speak-filter-table)
        value))

(defun emacspeak-speak-persist-filter-settings ()
  "Persist emacspeak filter settings for future sessions."
  (declare (special emacspeak-speak-filter-persistent-store
                    emacspeak-speak-filter-table))
  (let ((buffer (find-file-noselect
                 emacspeak-speak-filter-persistent-store)))
    (save-current-buffer
      (set-buffer buffer)
      (erase-buffer)
      (maphash 'emacspeak-speak-persist-filter-entry
               emacspeak-speak-filter-table)
      (save-buffer)
      (kill-buffer buffer))))

(defsubst emacspeak-speak-load-filter-settings ()
  "Load emacspeak filter settings.."
  (declare (special emacspeak-speak-filter-persistent-store
                    emacspeak-speak-filter-table
                    emacspeak-speak-filters-loaded-p))
  (unless emacspeak-speak-filters-loaded-p
    (load-file emacspeak-speak-filter-persistent-store)
    (setq emacspeak-speak-filters-loaded-p t)
    (add-hook 'kill-emacs-hook
              'emacspeak-speak-persist-filter-settings)))

(defun emacspeak-speak-line-set-column-filter (filter)
  "Set up filter for selectively speaking or ignoring portions of lines.
The filter is specified as a list of pairs.
For example, to filter  columns 1 -- 10 and 20 -- 25,
specify filter as
((0 9) (20 25)). Filter settings are persisted across sessions.  A
persisted filter is used as the default when prompting for a filter.
This allows one to accumulate a set of filters for specific files like
/var/adm/messages and /var/adm/maillog over time.
Option emacspeak-speak-line-invert-filter determines
the sense of the filter. "
  (interactive
   (list
    (progn
      (emacspeak-speak-load-filter-settings)
      (read-minibuffer
       (format
        "Specify columns to %s: "
        (if emacspeak-speak-line-invert-filter
            " speak"
          "filter out"))
       (format "%s"
               (if  (buffer-file-name )
                   (emacspeak-speak-lookup-persistent-filter (buffer-file-name))
                 ""))))))
  (cond
   ((and (listp filter)
         (every
          #'(lambda (l)
              (and (listp l)
                   (= 2 (length l))))
          filter))
    (setq emacspeak-speak-line-column-filter filter)
    (when (buffer-file-name)
      (emacspeak-speak-set-persistent-filter (buffer-file-name) filter)))
   (t
    (message "Unset column filter")
    (setq emacspeak-speak-line-column-filter nil))))

;;}}}                                   ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ; ;
;;{{{  Speak units of text              ; ; ;

(defsubst emacspeak-speak-region (start end )
  "Speak region.
Argument START  and END specify region to speak."
  (interactive "r" )
  (declare (special emacspeak-speak-voice-annotated-paragraphs
                    inhibit-point-motion-hooks))
  (let ((inhibit-point-motion-hooks t)
        (deactivate-mark nil))
    (when (not emacspeak-speak-voice-annotated-paragraphs)
      (save-restriction
        (narrow-to-region start end )
        (emacspeak-speak-voice-annotate-paragraphs)))
    (emacspeak-handle-action-at-point)
    (dtk-speak (buffer-substring start end ))))

(defsubst emacspeak-speak-string (string personality)
  "Apply personality to string and speak it."
  (put-text-property 0 (length string)
                     'personality personality string)
  (dtk-speak string))

(defcustom emacspeak-horizontal-rule "^\\([=_-]\\)\\1+$"
  "*Regular expression to match horizontal rules in ascii
text."
  :group 'emacspeak-speak
  :type 'string)

(put 'emacspeak-horizontal-rule 'variable-interactive
     "sEnterregular expression to match horizontal rule: ")

(defcustom emacspeak-decoration-rule
  "^[ \t!@#$%^&*()<>|_=+/\\,.;:-]+$"
  "*Regular expressions to match lines that are purely
decorative ascii."
  :group 'emacspeak-speak
  :type 'string)

(put 'emacspeak-decoration-rule 'variable-interactive
     "sEnterregular expression to match lines that are decorative ASCII: ")

(defcustom emacspeak-unspeakable-rule
  "^[^0-9a-zA-Z]+$"
  "*Pattern to match lines of special chars.
This is a regular expression that matches lines containing only
non-alphanumeric characters.  emacspeak will generate a tone
instead of speaking such lines when punctuation mode is set
to some."
  :group 'emacspeak-speak
  :type 'string)

(put 'emacspeak-unspeakable-rule 'variable-interactive
     "sEnterregular expression to match unspeakable lines: ")

(defcustom emacspeak-speak-maximum-line-length  512
  "*Threshold for determining `long' lines.
Emacspeak will ask for confirmation before speaking lines
that are longer than this length.  This is to avoid accidentally
opening a binary file and torturing the speech synthesizer
with a long string of gibberish."
  :group 'emacspeak-speak
  :type 'number)

(make-variable-buffer-local 'emacspeak-speak-maximum-line-length)

(defcustom emacspeak-speak-space-regexp
  (format "^[%c%c%c%c]+$"
          ?\240                         ; non-break space
          ?\                            ; Ascii 32
          ?\t                           ; tab
          ?\r                           ; CR
          )
  "Pattern that matches white space."
  :type 'string
  :group 'emacspeak)

(unless (fboundp 'format-mode-line)
  (defun format-mode-line (spec)
    "Process mode line format spec."
    (cond
;;; leaves                              ; ; ; ; ; ; ; ;
     ((symbolp spec) (symbol-value  spec))
     ((stringp spec) spec)
;;; leaf + tree:                        ; ; ; ; ; ; ; ;
     ((and (listp spec)
           (stringp (car spec)))
      (concat
       (car spec)
       (format-mode-line (cdr spec))))
     ((and (listp spec)
           (symbolp (car spec))
           (null (car spec)))
      (format-mode-line (cdr spec)))
     ((and (listp spec)
           (eq :eval  (car spec)))
      (eval (cadr spec)))
     ((and (listp spec)
           (symbolp (car spec)))
      (concat
       (format-mode-line (symbol-value (car spec)))
       (if (cdr spec)
           (format-mode-line (cdr spec))
         "")))
     ((and (listp spec)
           (caar spec))
      (concat
       (format-mode-line  (symbol-value (cadar spec)))
       (format-mode-line (cdr spec)))))))

;;;###autoload                          ;
(defun emacspeak-speak-line (&optional arg)
  "Speaks current line.  With prefix ARG, speaks the rest of the line
from point.  Negative prefix optional arg speaks from start of line to
point.  Voicifies if option `voice-lock-mode' is on.  Indicates
indentation with a tone if audio indentation is in use.  Indicates
position of point with an aural highlight if option
`emacspeak-show-point' is turned on --see command
`emacspeak-show-point' bound to \\[emacspeak-show-point].  Lines that
start hidden blocks of text, e.g.  outline header lines, or header
lines of blocks created by command `emacspeak-hide-or-expose-block'
are indicated with auditory icon ellipses."
  (interactive "P")
  (declare
   (special voice-animate voice-indent
            dtk-quiet dtk-stop-immediately dtk-punctuation-mode
            emacspeak-speak-line-invert-filter emacspeak-speak-space-regexp
            emacspeak-speak-maximum-line-length emacspeak-show-point
            emacspeak-decoration-rule emacspeak-horizontal-rule
            emacspeak-unspeakable-rule emacspeak-audio-indentation))
  (unless dtk-quiet 
    (when dtk-stop-immediately (dtk-stop))
    (when (listp arg) (setq arg (car arg )))
    (save-excursion
      (let ((inhibit-field-text-motion t)
            (start  nil)
            (end nil )
            (inhibit-point-motion-hooks t)
            (line nil)
            (orig (point))
            (indent nil))
        (beginning-of-line)
        (emacspeak-handle-action-at-point)
        (setq start (point))
        (setq end (line-end-position))
                                        ;determine what to speak based on prefix arg
        (cond
         ((null arg))
         ((> arg 0) (setq start orig))
         (t (setq end orig)))
        (setq line
              (if emacspeak-show-point
                  (ems-set-personality-temporarily
                   orig (1+ orig)
                   voice-animate (buffer-substring  start end ))
                (buffer-substring start end )))
        (when (and (null arg)
                   emacspeak-speak-line-column-filter)
          (setq line
                (emacspeak-speak-line-apply-column-filter
                 line emacspeak-speak-line-invert-filter)))
        (when (and emacspeak-audio-indentation (null arg ))
          (let ((limit (line-end-position)))
            (beginning-of-line)
            (skip-syntax-forward " " limit)
            (setq indent  (current-column )))
          (when (eq emacspeak-audio-indentation-method 'tone)
            (emacspeak-indent indent )))
        (when
            (or (invisible-p end)
                (get-text-property  start 'emacspeak-hidden-block))
          (emacspeak-auditory-icon 'ellipses))
        (cond
         ((string-equal ""  line)
          (dtk-tone 250   75 'force))
         ((string-match  emacspeak-speak-space-regexp  line) ;only white space
          (dtk-tone 300   120 'force))
         ((and (not (eq 'all dtk-punctuation-mode))
               (string-match  emacspeak-horizontal-rule line))
          (dtk-tone 350   100 t))
         ((and (not (eq 'all dtk-punctuation-mode))
               (string-match  emacspeak-decoration-rule line) )
          (dtk-tone 450   100 t))
         ((and (not (eq 'all dtk-punctuation-mode))
               (string-match  emacspeak-unspeakable-rule line))
          (dtk-tone 550   100 t))
         (t
          (let*
              ((l (length line))
               (speakable ;; should we speak this line?
                (cond
                 ((or selective-display
                      (< l emacspeak-speak-maximum-line-length)
                      (get-text-property start 'speak-line))
                  t)
                 ((y-or-n-p (format "Speak  this  %s long line? " l))
                  (setq emacspeak-speak-maximum-line-length (1+ l))
                  (with-silent-modifications
                    (put-text-property start end 'speak-line t))
                  t))))
            (when  speakable
              (cond
               ((and indent
                     (eq 'speak emacspeak-audio-indentation-method )
                     (null arg )
                     (> indent 0))
                (setq indent (format "indent %d" indent))
                (put-text-property   0 (length indent)
                                     'personality voice-indent   indent )
                (dtk-speak (concat indent line)))
               (t (dtk-speak line)))))))))))

(defvar emacspeak-speak-last-spoken-word-position nil
  "Records position of the last word that was spoken.
Local to each buffer.  Used to decide if we should spell the word
rather than speak it.")

(make-variable-buffer-local 'emacspeak-speak-last-spoken-word-position)
(defsubst emacspeak-speak-spell-word (word)
  "Spell WORD."
  (declare (special voice-animate))
  (let ((result "")
        (char-string ""))
    (loop for char across word
          do
          (setq char-string (format "%c " char))
          (when (and (<= ?A char)
                     (<= char ?Z))
            (put-text-property 0 1
                               'personality voice-animate
                               char-string)
            (setq char-string (format "cap %s " char-string)))
          (setq result
                (concat result
                        char-string)))
    (dtk-speak result)))

;;;###autoload
(defun emacspeak-speak-spell-current-word ()
  "Spell word at  point."
  (interactive)
  (emacspeak-speak-spell-word (word-at-point)))

;;;###autoload
(defun emacspeak-speak-word (&optional arg)
  "Speak current word.
With prefix ARG, speaks the rest of the word from point.
Negative prefix arg speaks from start of word to point.
If executed  on the same buffer position a second time, the word is
spelt instead of being spoken."
  (interactive "P")
  (declare (special emacspeak-speak-last-spoken-word-position))
  (when (listp arg) (setq arg (car arg )))
  (emacspeak-handle-action-at-point)
  (save-excursion
    (let ((orig (point))
          (inhibit-point-motion-hooks t)
          (start nil)
          (end nil)
          (speaker 'dtk-speak))
      (forward-word 1)
      (setq end (point))
      (backward-word 1)
      (setq start (min orig  (point)))
      (cond
       ((null arg ))
       ((> arg 0) (setq start orig))
       ((< arg 0) (setq end orig )))
      ;; select speak or spell
      (cond
       ((and (ems-interactive-p )
             (eq emacspeak-speak-last-spoken-word-position orig))
        (setq speaker 'emacspeak-speak-spell-word)
        (setq emacspeak-speak-last-spoken-word-position nil))
       (t (setq  emacspeak-speak-last-spoken-word-position orig)))
      (funcall speaker  (buffer-substring  start end )))))

(defsubst emacspeak-is-alpha-p (c)
  "Check if argument C is an alphabetic character."
  (and (= ?w (char-syntax c))
       (dtk-unicode-char-untouched-p c)))

;;{{{  phonemic table

(defvar emacspeak-char-to-phonetic-table
  '(
    ("1"  . "one")
    ("2" .  "two")
    ("3" .  "three")
    ("4" .  "four")
    ("5" .  "five")
    ("6" .  "six")
    ("7" .  "seven")
    ("8" .  "eight")
    ("9" .  "nine")
    ("0".  "zero")
    ("a" . "alpha" )
    ("b" . "bravo")
    ("c" .  "charlie")
    ("d" . "delta")
    ("e" . "echo")
    ("f" . "foxtrot")
    ("g" . "golf")
    ("h" . "hotel")
    ("i" . "india")
    ("j" . "juliet")
    ("k" . "kilo")
    ("l" . "lima")
    ("m" . "mike")
    ("n" . "november")
    ("o" . "oscar")
    ("p" . "poppa")
    ("q" . "quebec")
    ("r" . "romeo")
    ("s" . "sierra")
    ("t" . "tango")
    ("u" . "uniform")
    ("v" . "victor")
    ("w" . "whisky")
    ("x" . "xray")
    ("y" . "yankee")
    ("z" . "zulu")
    ("A" . "cap alpha" )
    ("B" . "cap bravo")
    ("C" .  "cap charlie")
    ("D" . "cap delta")
    ("E" . "cap echo")
    ("F" . "cap foxtrot")
    ("G" . "cap golf")
    ("H" . "cap hotel")
    ("I" . "cap india")
    ("J" . "cap juliet")
    ("K" . "cap kilo")
    ("L" . "cap lima")
    ("M" . "cap mike")
    ("N" . "cap november")
    ("O" . "cap oscar")
    ("P" . "cap poppa")
    ("Q" . "cap quebec")
    ("R" . "cap romeo")
    ("S" . "cap sierra")
    ("T" . "cap tango")
    ("U" . "cap uniform")
    ("V" . "cap victor")
    ("W" . "cap whisky")
    ("X" . "cap xray")
    ("Y" . "cap yankee")
    ("Z" . "cap zulu"))
  "Mapping from characters to their phonemic equivalents.")

(defun emacspeak-get-phonetic-string (char)
  "Return the phonetic string for this CHAR or its upper case equivalent.
char is assumed to be one of a--z."
  (declare (special emacspeak-char-to-phonetic-table))
  (let ((char-string   (char-to-string char )))
    (or   (cdr
           (assoc char-string emacspeak-char-to-phonetic-table ))
          (dtk-unicode-full-name-for-char char)
          " ")))

;;}}}
;;{{{ Speak Chars:

(defsubst emacspeak-speak-this-char (char)
  "Speak this CHAR."
  (when char
    (cond
     ((emacspeak-is-alpha-p char) (dtk-letter (char-to-string
                                               char )))
     ((> char 128) (emacspeak-speak-char-name char))
     (t (dtk-dispatch (dtk-char-to-speech char ))))))
;;;###autoload
(defun emacspeak-speak-char (&optional prefix)
  "Speak character under point.
Pronounces character phonetically unless  called with a PREFIX arg."
  (interactive "P")
  (let ((char  (following-char ))
        (display (get-char-property (point) 'display)))
    (when char
      (cond
       ((stringp display) (dtk-speak display))
       ((> char 128) (emacspeak-speak-char-name char))
       ((and (not prefix)
             (emacspeak-is-alpha-p char))
        (dtk-speak (emacspeak-get-phonetic-string char )))
       (t (emacspeak-speak-this-char char))))))

;;;###autoload
(defun emacspeak-speak-preceding-char ()
  "Speak character before point."
  (interactive)
  (let ((char  (preceding-char ))
        (display (get-char-property (1- (point)) 'display)))
    (when char
      (cond
       ((stringp display) (dtk-speak display))
       ((> char 128) (emacspeak-speak-char-name char))
       (t (emacspeak-speak-this-char char))))))

;;;###autoload
(defun emacspeak-speak-char-name (char)
  "tell me what this is"
  (interactive)
  (dtk-speak (dtk-unicode-name-for-char char)))

;;}}}

;;{{{ emacspeak-speak-display-char

;;;###autoload
(defun emacspeak-speak-display-char  (&optional prefix)
  "Display char under point using current speech display table.
Behavior is the same as command `emacspeak-speak-char'
bound to \\[emacspeak-speak-char]
for characters in the range 0--127.
Optional argument PREFIX  specifies that the character should be spoken phonetically."
  (interactive "P")
  (declare (special dtk-display-table ))
  (let ((char (following-char )))
    (cond
     ((and dtk-display-table
           (> char 127))
      (dtk-dispatch (aref dtk-display-table char)))
     (t (emacspeak-speak-char prefix)))))

;;}}}
;;{{{ emacspeak-speak-set-display-table

(defvar emacspeak-speak-display-table-list
  '(("iso ascii" . "iso ascii")
    ("default" . "default"))
  "Available speech display tables.")

;;;###autoload
(defun emacspeak-speak-set-display-table(&optional prefix)
  "Sets up buffer specific speech display table that controls how
special characters are spoken. Interactive prefix argument causes
setting to be global."
  (interactive "P")
  (declare (special dtk-display-table
                    dtk-iso-ascii-character-to-speech-table
                    emacspeak-speak-display-table-list))
  (let ((type (completing-read
               "Select speech display table: "
               emacspeak-speak-display-table-list
               nil t ))
        (table nil))
    (cond
     ((string-equal "iso ascii" type)
      (setq table dtk-iso-ascii-character-to-speech-table))
     (t (setq table nil)))
    (cond
     (prefix
      (setq-default dtk-display-table table )
      (setq dtk-display-table table))
     (t (setq dtk-display-table table)))))

;;}}}
;;;###autoload
(defun emacspeak-speak-sentence (&optional arg)
  "Speak current sentence.
With prefix ARG, speaks the rest of the sentence  from point.
Negative prefix arg speaks from start of sentence to point."
  (interactive "P" )
  (when (listp arg) (setq arg (car arg )))
  (save-excursion
    (let ((orig (point))
          (inhibit-point-motion-hooks t)
          (start nil)
          (end nil))
      (forward-sentence 1)
      (setq end (point))
      (backward-sentence 1)
      (setq start (point))
      (emacspeak-handle-action-at-point)
      (cond
       ((null arg ))
       ((> arg 0) (setq start orig))
       ((< arg 0) (setq end orig )))
      (dtk-speak (buffer-substring start end )))))

;;;###autoload
(defun emacspeak-speak-sexp (&optional arg)
  "Speak current sexp.
With prefix ARG, speaks the rest of the sexp  from point.
Negative prefix arg speaks from start of sexp to point.
If option  `voice-lock-mode' is on, then uses the personality."
  (interactive "P" )
  (when (listp arg) (setq arg (car arg )))
  (save-excursion
    (let ((orig (point))
          (inhibit-point-motion-hooks t)
          (start nil)
          (end nil))
      (condition-case nil
          (forward-sexp 1)
        (error nil ))
      (setq end (point))
      (condition-case nil
          (backward-sexp 1)
        (error nil ))
      (setq start (point))
      (emacspeak-handle-action-at-point)
      (cond
       ((null arg ))
       ((> arg 0) (setq start orig))
       ((< arg 0) (setq end orig )))
      (dtk-speak (buffer-substring  start end )))))

;;;###autoload
(defun emacspeak-speak-page (&optional arg)
  "Speak a page.
With prefix ARG, speaks rest of current page.
Negative prefix arg will read from start of current page to point.
If option  `voice-lock-mode' is on, then it will use any defined personality."
  (interactive "P")
  (when (listp arg) (setq arg (car arg )))
  (save-excursion
    (let ((orig (point))
          (inhibit-point-motion-hooks t)
          (start nil)
          (end nil))
      (mark-page)
      (setq start  (point))
      (emacspeak-handle-action-at-point)
      (setq end  (mark))
      (cond
       ((null arg ))
       ((> arg 0) (setq start orig))
       ((< arg 0) (setq end orig )))
      (dtk-speak (buffer-substring start end )))))

;;;###autoload
(defun emacspeak-speak-paragraph(&optional arg)
  "Speak paragraph.
With prefix arg, speaks rest of current paragraph.
Negative prefix arg will read from start of current paragraph to point.
If voice-lock-mode is on, then it will use any defined personality. "
  (interactive "P")
  (when (listp arg) (setq arg (car arg )))
  (save-excursion
    (let ((orig (point))
          (inhibit-point-motion-hooks t)
          (start nil)
          (end nil))
      (forward-paragraph 1)
      (setq end (point))
      (backward-paragraph 1)
      (setq start (point))
      (emacspeak-handle-action-at-point)
      (cond
       ((null arg ))
       ((> arg 0) (setq start orig))
       ((< arg 0) (setq end orig )))
      (dtk-speak (buffer-substring  start end )))))

;;}}}
;;{{{  Speak buffer objects such as help, completions minibuffer etc

;;;###autoload
(defun emacspeak-speak-buffer (&optional arg)
  "Speak current buffer  contents.
With prefix ARG, speaks the rest of the buffer from point.
Negative prefix arg speaks from start of buffer to point.
 If voice lock mode is on, the paragraphs in the buffer are
voice annotated first,  see command `emacspeak-speak-voice-annotate-paragraphs'."
  (interactive "P" )
  (declare (special emacspeak-speak-voice-annotated-paragraphs
                    inhibit-point-motion-hooks))
  (let ((inhibit-point-motion-hooks t))
    (when (not emacspeak-speak-voice-annotated-paragraphs)
      (emacspeak-speak-voice-annotate-paragraphs))
    (when (listp arg) (setq arg (car arg )))
    (let ((start nil )
          (end nil))
      (cond
       ((null arg)
        (setq start (point-min)
              end (point-max)))
       ((> arg 0)
        (setq start (point)
              end (point-max)))
       (t (setq start (point-min)
                end (point))))
      (dtk-speak (buffer-substring start end )))))

;;;###autoload
(defun emacspeak-speak-other-buffer (buffer)
  "Speak specified buffer.
Useful to listen to a buffer without switching  contexts."
  (interactive
   (list
    (read-buffer "Speak buffer: "
                 nil t)))
  (save-current-buffer
    (set-buffer buffer)
    (emacspeak-speak-buffer)))

;;;###autoload
(defun emacspeak-speak-front-of-buffer()
  "Speak   the buffer from start to   point"
  (interactive)
  (emacspeak-speak-buffer -1))

;;;###autoload
(defun emacspeak-speak-rest-of-buffer()
  "Speak remainder of the buffer starting at point"
  (interactive)
  (emacspeak-auditory-icon 'select-object)
  (emacspeak-speak-buffer 1))

;;;###autoload
(defun emacspeak-speak-help(&optional arg)
  "Speak help buffer if one present.
With prefix arg, speaks the rest of the buffer from point.
Negative prefix arg speaks from start of buffer to point."
  (interactive "P")
  (declare (special help-buffer-list))
  (let ((help-buffer
         (if (boundp 'help-buffer-list)
             (car help-buffer-list)
           (get-buffer "*Help*"))))
    (cond
     (help-buffer
      (save-current-buffer
        (set-buffer help-buffer)
        (emacspeak-speak-buffer arg )))
     (t (dtk-speak "First ask for help" )))))

;;;###autoload

;;;###autoload
(defun emacspeak-speak-minibuffer(&optional arg)
  "Speak the minibuffer contents
 With prefix arg, speaks the rest of the buffer from point.
Negative prefix arg speaks from start of buffer to point."
  (interactive "P" )
  (let ((minibuff (window-buffer (minibuffer-window ))))
    (save-current-buffer
      (set-buffer minibuff)
      (emacspeak-speak-buffer arg))))

;;;###autoload
(defun emacspeak-get-current-completion  ()
  "Return the completion string under point in the *Completions* buffer."
  (let (beg end)
    (if (and (not (eobp)) (get-text-property (point) 'mouse-face))
        (setq end (point) beg (1+ (point))))
    (if (and (not (bobp)) (get-text-property (1- (point)) 'mouse-face))
        (setq end (1- (point)) beg (point)))
    (if (null beg)
        (error "No current  completion "))
    (setq beg (or
               (previous-single-property-change beg 'mouse-face)
               (point-min)))
    (setq end (or (next-single-property-change end 'mouse-face) (point-max)))
    (buffer-substring beg end)))

;;}}}
;;{{{ mail check
(defcustom emacspeak-mail-spool-file
  (expand-file-name
   (user-login-name)
   (if (boundp 'rmail-spool-directory)
       rmail-spool-directory
     "/usr/spool/mail/"))
  "Mail spool file examined  to alert you about newly
arrived mail."
  :type '(choice
          (const :tag "None" nil)
          (file :tag "Mail drop location"))
  :group 'emacspeak-speak)

(defcustom emacspeak-voicemail-spool-file
  nil
  "Mail spool file examined  to alert you about newly
arrived voicemail."
  :type '(choice
          (const :tag "None" nil)
          (file :tag "VoiceMail drop location"))
  :group 'emacspeak-speak)

(defsubst emacspeak-get-file-size (filename)
  "Return file size for file FILENAME."
  (or (nth 7 (file-attributes filename))
      0))

(defvar emacspeak-mail-last-alerted-time (list 0 0)
  "Least  significant 16 digits of the time when mail alert was last issued.
Alert the user only if mail has arrived since this time in the
  future.")

(defsubst emacspeak-mail-get-last-mail-arrival-time (f)
  "Return time when mail  last arrived."
  (if (file-exists-p f)
      (nth 5 (file-attributes f ))
    0))

(defcustom emacspeak-mail-alert-interval  300
  "Interval in seconds between mail alerts for the same pending
  message."
  :type 'integer
  :group 'emacspeak-speak)
(unless (fboundp 'time-add )
  (defun time-add (t1 t2) ;;; for pre emacs 21.4
    "Add two time values.  One should represent a time difference."
    (let ((high (car t1))
          (low (if (consp (cdr t1)) (nth 1 t1) (cdr t1)))
          (micro (if (numberp (car-safe (cdr-safe (cdr t1))))
                     (nth 2 t1)
                   0))
          (high2 (car t2))
          (low2 (if (consp (cdr t2)) (nth 1 t2) (cdr t2)))
          (micro2 (if (numberp (car-safe (cdr-safe (cdr t2))))
                      (nth 2 t2)
                    0)))
      ;; Add
      (setq micro (+ micro micro2))
      (setq low (+ low low2))
      (setq high (+ high high2))

      ;; Normalize
      ;; `/' rounds towards zero while `mod' returns a positive number,
      ;; so we can't rely on (= a (+ (* 100 (/ a 100)) (mod a 100))).
      (setq low (+ low (/ micro 1000000) (if (< micro 0) -1 0)))
      (setq micro (mod micro 1000000))
      (setq high (+ high (/ low 65536) (if (< low 0) -1 0)))
      (setq low (logand low 65535))

      (list high low micro))))
(defsubst  emacspeak-mail-alert-user-p (f)
  "Predicate to check if we need to play an alert for the specified spool."
  (declare (special emacspeak-mail-last-alerted-time
                    emacspeak-mail-alert-interval))
  (let* ((mod-time (emacspeak-mail-get-last-mail-arrival-time f))
         (size (emacspeak-get-file-size f))
         (result (and (> size 0)
                      (or
                       (time-less-p emacspeak-mail-last-alerted-time mod-time) ; new mail
                       (time-less-p     ;unattended mail
                        (time-add emacspeak-mail-last-alerted-time
                                  (list 0 emacspeak-mail-alert-interval))
                        (current-time))))))
    (when result
      (setq emacspeak-mail-last-alerted-time  (current-time)))
    result))

(defun emacspeak-mail-alert-user ()
  "Alerts user about the arrival of new mail."
  (declare (special emacspeak-mail-spool-file emacspeak-voicemail-spool-file))
  (when (and emacspeak-mail-spool-file
             (emacspeak-mail-alert-user-p emacspeak-mail-spool-file))
    (emacspeak-auditory-icon 'new-mail))
  (when (and emacspeak-voicemail-spool-file
             (emacspeak-mail-alert-user-p emacspeak-voicemail-spool-file))
    (emacspeak-auditory-icon 'voice-mail)))

(defcustom emacspeak-mail-alert t
  "*Option to indicate cueing of new mail.
If t, emacspeak will alert you about newly arrived mail
with an auditory icon when
displaying the mode line.
You can use command
`emacspeak-toggle-mail-alert' bound to
\\[emacspeak-toggle-mail-alert] to set this option.
If you have online access to a voicemail drop, you can have a
  voice-mail alert set up by specifying the location of the
  voice-mail drop via custom option
emacspeak-voicemail-spool-file."
  :group 'emacspeak-speak
  :type 'boolean)

(ems-generate-switcher ' emacspeak-toggle-mail-alert
                         'emacspeak-mail-alert
                         "Toggle state of  Emacspeak  mail alert.
Interactive PREFIX arg means toggle  the global default value, and then set the
current local  value to the result.
Turning on this option results in Emacspeak producing an auditory icon
indicating the arrival  of new mail when displaying the mode line.")

;;}}}
;;{{{ Cache Voicefied mode-names

(defvar emacspeak-voicefied-mode-names
  (make-hash-table :test 'eq)
  "Hash table mapping mode-names to their voicefied equivalents.")

(defsubst emacspeak-get-voicefied-mode-name (mode-name)
  "Return voicefied version of this mode-name."
  (declare (special emacspeak-voicefied-mode-names))
  (let* ((mode-name-str
          (if (stringp mode-name)
              mode-name
            (format-mode-line mode-name)))
         (result (gethash mode-name-str emacspeak-voicefied-mode-names)))
    (or result
        (progn
          (setq result (copy-sequence mode-name-str))
          (put-text-property 0 (length result)
                             'personality voice-animate result)
          (puthash mode-name-str result emacspeak-voicefied-mode-names)
          result))))

;;}}}
;;{{{ Cache Voicefied buffer-names

(defvar emacspeak-voicefied-buffer-names
  (make-hash-table :test 'eq)
  "Hash table mapping buffer-names to their voicefied equivalents.")

(defsubst emacspeak-get-voicefied-buffer-name (buffer-name)
  "Return voicefied version of this buffer-name."
  (declare (special emacspeak-voicefied-buffer-names))
  (let ((result (gethash buffer-name emacspeak-voicefied-buffer-names)))
    (or result
        (progn
          (setq result (copy-sequence buffer-name))
          (put-text-property 0 (length result)
                             'personality voice-lighten-medium result)
          (puthash buffer-name result emacspeak-voicefied-buffer-names)
          result))))

(defvar emacspeak-voicefied-recursion-info
  (make-hash-table :test 'eq)
  "Hash table mapping recursive-depth levels  to their voicefied equivalents.")

(defsubst emacspeak-get-voicefied-recursion-info (level)
  "Return voicefied version of this recursive-depth level."
  (declare (special emacspeak-voicefied-recursion-info))
  (cond
   ((zerop level) "")
   (t 
    (let ((result (gethash level emacspeak-voicefied-recursion-info)))
      (or result
          (progn
            (setq result (format " Recursive Edit %d " level))
            (put-text-property 0 (length result)
                               'personality voice-smoothen result)
            (puthash level result emacspeak-voicefied-buffer-names)
            result))))))

(defvar emacspeak-voicefied-frame-info
  (make-hash-table)
  "Hash table mapping frame names  levels  to their voicefied equivalents.")

(defsubst emacspeak-get-voicefied-frame-info (frame)
  "Return voicefied version of this frame name."
  (declare (special emacspeak-voicefied-frame-info))
  (cond
   ((= (length (frame-list)) 1) " ")
   (t
    (let ((frame-name (frame-parameter frame 'name))
          (frame-info nil))
      (or (gethash  frame-name emacspeak-voicefied-frame-info)
          (progn
            ( setq frame-info (format " %s " frame-name))
            (put-text-property 0 (length frame-info)
                               'personality voice-lighten-extra frame-info)
            (puthash  frame-name frame-info emacspeak-voicefied-frame-info)
            frame-info))))))

;;}}}
;;{{{  Speak mode line information

;;;compute current line number
(defsubst emacspeak-get-current-line-number()
  (let ((start (point)))
    (save-excursion
      (save-restriction
        (widen)
        (goto-char (point-min))
        (+ 1 (count-lines start (point)))))))

;;; make line-number-mode buffer local
(declaim (special line-number-mode))
(make-variable-buffer-local 'line-number-mode)
(setq-default line-number-mode nil)

;;; make column-number-mode buffer local
(declaim (special column-number-mode))
(make-variable-buffer-local 'column-number-mode)
(setq-default column-number-mode nil)
;;{{{   mode line speaker

(defsubst emacspeak-speak-which-function ()
  "Speak which function we are on.  Uses which-function from
which-func without turning that mode on.  We actually use
semantic to do the work."
  (declare (special semantic--buffer-cache))
  (when  (and (featurep 'semantic) semantic--buffer-cache)
    (require 'which-func)
    (message  (or
               (which-function)
               "Not inside a function."))))
;;; not used

(defun emacspeak-speak-buffer-info ()
  "Speak buffer information."
  (message "Buffer has %s lines and %s characters %s "
           (count-lines (point-min) (point-max))
           (- (point-max) (point-min))
           (if (= 1 (point-min))
               ""
             "with narrowing in effect. ")))
(voice-setup-map-face 'header-line 'voice-bolden)

(defun emacspeak-speak-mode-line (&optional buffer-info)
  "Speak the mode-line.
Speaks header-line if that is set when called non-interactively.
Interactive prefix arg speaks buffer info."
  (interactive "P")
  (declare (special  mode-name  major-mode 
                     header-line-format global-mode-string
                     column-number-mode line-number-mode
                     emacspeak-mail-alert mode-line-format ))
  (force-mode-line-update)
  (emacspeak-dtk-sync)
  (when   emacspeak-mail-alert (emacspeak-mail-alert-user))
  (cond
   ((and header-line-format (not (ems-interactive-p )))
    (emacspeak-speak-header-line))
   (buffer-info (emacspeak-speak-buffer-info))
   (t
    (dtk-stop)
    (let ((dtk-stop-immediately nil )
          (global-info (format-mode-line global-mode-string))
          (frame-info (emacspeak-get-voicefied-frame-info (selected-frame)))
          (recursion-info (emacspeak-get-voicefied-recursion-info  (recursion-depth)))
          (dir-info (when (or (eq major-mode 'shell-mode)
                              (eq major-mode 'comint-mode))
                      (abbreviate-file-name default-directory))))
      (cond
       ((stringp mode-line-format) (dtk-speak mode-line-format ))
       (t                               ;process modeline
        (unless (and buffer-read-only (buffer-modified-p))
                                        ; avoid pathological case
          (when (and buffer-file-name  (buffer-modified-p)) (dtk-tone 950 100))
          (when buffer-read-only (dtk-tone 250 100)))
        (put-text-property 0 (length global-info)
                           'personality voice-bolden-medium global-info)
        (tts-with-punctuations
         'all
         (dtk-speak
          (concat
           dir-info
           (emacspeak-get-voicefied-buffer-name (buffer-name))
           (when line-number-mode
             (format "line %d" (emacspeak-get-current-line-number)))
           (when column-number-mode
             (format "Column %d" (current-column)))
           (emacspeak-get-voicefied-mode-name mode-name)
           (emacspeak-get-current-percentage-verbously)
           global-info
           frame-info
           recursion-info)))))))))

(defun emacspeak-speak-current-buffer-name ()
  "Speak name of current buffer."
  (tts-with-punctuations 'all
                         (dtk-speak
                          (buffer-name))))

;;}}}
;;;Helper --return string describing coding system info

(defvar emacspeak-speak-default-os-coding-system
  (default-value 'buffer-file-coding-system)
  "Default coding system used for text files.
This should eventually be initialized based on the OS we are
running under.")

(defsubst ems-get-buffer-coding-system ()
  "Return buffer coding system info if releant.
If emacspeak-speak-default-os-coding-system is set and matches the
current coding system, then we return an empty string."
  (declare (special buffer-file-coding-system voice-lighten
                    emacspeak-speak-default-os-coding-system))
  (cond
   ((and (boundp 'buffer-file-coding-system)
         buffer-file-coding-system
         emacspeak-speak-default-os-coding-system
         (not (eq buffer-file-coding-system emacspeak-speak-default-os-coding-system)))
    (let ((value (format "%s" buffer-file-coding-system)))
      (put-text-property 0  (length value)
                         'personality
                         voice-lighten
                         value)
      value))
   (t "")))

(defvar emacspeak-minor-mode-prefix
  "Active: " 
  "Prefix used in composing utterance produced by emacspeak-speak-minor-mode-line.")

(put-text-property 0 (length emacspeak-minor-mode-prefix)
                   'personality voice-annotate emacspeak-minor-mode-prefix)

;;;###autoload
(defun emacspeak-speak-minor-mode-line ()
  "Speak the minor mode-information."
  (interactive)
  (declare (special minor-mode-alist emacspeak-minor-mode-prefix
                    vc-mode))
  (force-mode-line-update)
  (let ((info nil))
    (setq info
          (mapconcat
           #'(lambda(item)
               (let ((var (car item))
                     (value (cadr item )))
                 (if (and (boundp var) (eval var))
                     (format-mode-line  value)
                   "")))
           minor-mode-alist
           " "))
    (dtk-speak
     (concat emacspeak-minor-mode-prefix
             vc-mode info
             (ems-get-buffer-coding-system)))))

(defalias 'emacspeak-speak-line-number 'what-line)

;;;###autoload
(defun emacspeak-speak-buffer-filename (&optional filename)
  "Speak name of file being visited in current buffer.
Speak default directory if invoked in a dired buffer,
or when the buffer is not visiting any file.
Interactive prefix arg `filename' speaks only the final path
component.
The result is put in the kill ring for convenience."
  (interactive "P")
  (let ((location (or (buffer-file-name)
                      default-directory)))
    (when filename
      (setq location
            (file-name-nondirectory location)))
    (kill-new location)
    (dtk-speak
     location)))

;;}}}
;;{{{ Speak header-line

;;;###autoload
(defcustom emacspeak-use-header-line t
  "Use default header line defined  by Emacspeak for buffers that
dont customize the header."
  :type 'boolean
  :group 'emacspeak)

(defvar emacspeak-header-line-format
  '((:eval (buffer-name)))
  "Default header-line-format defined by Emacspeak.
Displays name of current buffer.")

(defun emacspeak-speak-header-line ()
  "Speak header line if set."
  (interactive)
  (declare (special header-line-format))
  (cond
   (header-line-format
    (dtk-speak (format-mode-line header-line-format)))
   (t (dtk-speak "No header line.")))
  (emacspeak-auditory-icon 'item))

;;;###autoload
(defun emacspeak-toggle-header-line ()
  "Toggle Emacspeak's default header line."
  (interactive)
  (declare (special emacspeak-header-line-format
                    header-line-format))
  (if header-line-format
      (setq header-line-format nil)
    (setq header-line-format emacspeak-header-line-format))
  (emacspeak-auditory-icon (if header-line-format 'on 'off))
  (message "Turned %s default header line."
           (if header-line-format 'on 'off)))

;;}}}
;;{{{  Speak text without moving point

;;; Functions to browse without moving:
(defun emacspeak-read-line-internal(arg)
  "Read a line without moving.
Line to read is specified relative to the current line, prefix args gives the
offset. Default  is to speak the previous line. "
  (save-excursion
    (cond
     ((zerop arg) (emacspeak-speak-line ))
     ((zerop (forward-line arg))
      (emacspeak-speak-line ))
     (t (dtk-speak "Not that many lines in buffer ")))))

;;;###autoload
(defun emacspeak-read-previous-line(&optional arg)
  "Read previous line, specified by an offset, without moving.
Default is to read the previous line. "
  (interactive "p")
  (emacspeak-read-line-internal (- (or arg 1 ))))

;;;###autoload
(defun emacspeak-read-next-line(&optional arg)
  "Read next line, specified by an offset, without moving.
Default is to read the next line. "
  (interactive "p")
  (emacspeak-read-line-internal (or arg 1 )))

(defun emacspeak-read-word-internal(arg)
  "Read a word without moving.
word  to read is specified relative to the current word, prefix args gives the
offset. Default  is to speak the previous word. "
  (save-excursion
    (cond
     ((= arg 0) (emacspeak-speak-word ))
     ((forward-word arg)
      (skip-syntax-forward " ")
      (emacspeak-speak-word 1 ))
     (t (dtk-speak "Not that many words ")))))

;;;###autoload
(defun emacspeak-read-previous-word(&optional arg)
  "Read previous word, specified as a prefix arg, without moving.
Default is to read the previous word. "
  (interactive "p")
  (emacspeak-read-word-internal (- (or arg 1 ))))

;;;###autoload
(defun emacspeak-read-next-word(&optional arg)
  "Read next word, specified as a numeric  arg, without moving.
Default is to read the next word. "
  (interactive "p")
  (emacspeak-read-word-internal  (or arg 1 )))

;;}}}
;;{{{  Speak misc information e.g. time, version, current-kill  etc

(defcustom emacspeak-speak-time-format-string
  "%_I %M %p on %A, %B %_e, %Y "
  "*Format string that specifies how the time should be spoken.
See the documentation for function
`format-time-string'"
  :group 'emacspeak-speak
  :type 'string)
;;{{{ world clock

(defcustom emacspeak-speak-zoneinfo-directory
  "/usr/share/zoneinfo/"
  "Directory containing timezone data."
  :type 'directory
  :group 'emacspeak-speak)
;;;###autoload
(defun emacspeak-speak-world-clock (zone &optional set)
  "Display current date and time  for specified zone.
Optional second arg `set' sets the TZ environment variable as well."
  (interactive
   (list
    (let ((completion-ignore-case t)
          (read-file-name-completion-ignore-case t))
      (substring
       (read-file-name
        "Timezone: "
        emacspeak-speak-zoneinfo-directory)
       (length emacspeak-speak-zoneinfo-directory)))
    current-prefix-arg))
  (declare (special emacspeak-speak-time-format-string
                    emacspeak-speak-zoneinfo-directory))
  (when (and set
             (= 16 (car set)))
    ;; two interactive prefixes from caller
    (setenv "TZ" zone))
  (emacspeak-shell-command
   (format "export TZ=%s; date +\"%s\""
           zone
           (concat emacspeak-speak-time-format-string
                   (format
                    " in %s, %%Z, %%z "
                    zone)))))

;;}}}
;;;###autoload
(defun emacspeak-speak-time (&optional world)
  "Speak the time.
Optional interactive prefix arg `C-u'invokes world clock.
Timezone is specified using minibuffer completion.
Second interactive prefix sets clock to new timezone."
  (interactive "P")
  (declare (special emacspeak-speak-time-format-string))
  (cond
   (world
    (call-interactively 'emacspeak-speak-world-clock))
   (t
    (tts-with-punctuations 'some
                           (dtk-speak
                            (propertize
                             (format-time-string
                              emacspeak-speak-time-format-string)
                             'personality voice-punctuations-some))))))

;;;###autoload
(defun emacspeak-speak-version ()
  "Announce version information for running emacspeak."
  (interactive)
  (declare (special emacspeak-version
                    voice-animate voice-bold
                    emacspeak-sounds-directory
                    emacspeak-use-auditory-icons
                    emacspeak-codename))
  (let ((signature "You are using  ")
        (version (format "Emacspeak %s" emacspeak-version)))
    (put-text-property 0 (length version)
                       'personality voice-animate version)
    (put-text-property 0 (length emacspeak-codename)
                       'personality voice-bolden
                       emacspeak-codename)
    (when (and  emacspeak-use-auditory-icons
                (file-exists-p "/usr/bin/mpg123"))
      (start-process "mp3" nil "mpg123"
                     "-q"
                     (expand-file-name "emacspeak.mp3" emacspeak-sounds-directory)))
    (tts-with-punctuations 'some
                           (dtk-speak
                            (concat signature
                                    version
                                    emacspeak-codename)))))

;;;###autoload
(defun emacspeak-speak-current-kill (count)
  "Speak the current kill entry.
This is the text that will be yanked in by the next \\[yank].
Prefix numeric arg, COUNT, specifies that the text that will be yanked as a
result of a
\\[yank]  followed by count-1 \\[yank-pop]
be spoken.
 The kill number that is spoken says what numeric prefix arg to give
to command yank."
  (interactive "p")
  (let (
        (context
         (format "kill %s "
                 (if current-prefix-arg (+ 1 count)  1 ))))
    (put-text-property 0 (length context)
                       'personality voice-annotate context )
    (dtk-speak
     (concat
      context
      (current-kill (if current-prefix-arg count 0)t)))))

;;;###autoload
(defun emacspeak-zap-tts ()
  "Send this command to the TTS directly."
  (interactive)
  (dtk-dispatch
   (read-from-minibuffer"Enter TTS command string: ")))

(defun emacspeak-speak-string-to-phone-number (string)
  "Convert alphanumeric phone number to true phone number.
Argument STRING specifies the alphanumeric phone number."
  (setq string (downcase string ))
  (let ((i 0))
    (loop for character across string
          do
          (aset string i
                (case character
                  (?a  ?2)
                  (?b ?2)
                  (?c ?2)
                  (?d ?3)
                  (?e ?3)
                  (?f ?3)
                  (?g ?4)
                  (?h ?4)
                  (?i ?4)
                  (?j ?5)
                  (?k ?5)
                  (?l ?5)
                  (?m ?6)
                  (?n ?6)
                  (?o ?6)
                  (?p ?7)
                  (?r ?7)
                  (?s ?7)
                  (?t ?8)
                  (?u ?8)
                  (?v ?8)
                  (?w ?9)
                  (?x ?9)
                  (?y ?9)
                  (?q ?1)
                  (?z ?1)
                  (otherwise character)))
          (incf i))
    string))

;;;###autoload
(defun emacspeak-dial-dtk (number)
  "Prompt for and dial a phone NUMBER with the Dectalk."
  (interactive "sEnter phone number to dial:")
  (let ((dtk-stop-immediately nil))
    (dtk-dispatch (format "[:dial %s]"
                          (emacspeak-speak-string-to-phone-number number)))
    (sit-for 4)))

;;}}}
;;{{{ speaking marks

;;; Intelligent mark feedback for emacspeak:
;;;

;;;###autoload
(defun emacspeak-speak-current-mark (count)
  "Speak the line containing the mark.
With no argument, speaks the
line containing the mark--this is where `exchange-point-and-mark'
\\[exchange-point-and-mark] would jump.  Numeric prefix arg 'COUNT' speaks
line containing mark 'n' where 'n' is one less than the number of
times one has to jump using `set-mark-command' to get to this marked
position.  The location of the mark is indicated by an aural highlight
achieved by a change in voice personality."
  (interactive "p")
  (unless (mark)
    (error "No marks set in this buffer"))
  (when (and current-prefix-arg
             (> count (length mark-ring)))
    (error "Not that many marks in this buffer"))
  (let (
        (line nil)
        (position nil)
        (context
         (format "mark %s "
                 (if current-prefix-arg count   0 ))))
    (put-text-property 0 (length context)
                       'personality voice-annotate context )
    (setq position
          (if current-prefix-arg
              (elt mark-ring(1-  count))
            (mark)))
    (save-excursion
      (goto-char position)
      (ems-set-personality-temporarily
       position (1+ position) voice-animate
       (setq line
             (thing-at-point  'line ))))
    (dtk-speak
     (concat context line))))

;;}}}
;;{{{ speaking personality chunks

;;;###autoload
(defun emacspeak-speak-this-personality-chunk ()
  "Speak chunk of text around point that has current
personality."
  (interactive)
  (let ((personality (get-text-property (point) 'personality))
        (start (previous-single-property-change (point) 'personality))
        (end (next-single-property-change  (point) 'personality)))
    (emacspeak-speak-region
     (or start (point-min))
     (or end (point-max)))))

;;;###autoload
(defun emacspeak-speak-next-personality-chunk ()
  "Moves to the front of next chunk having current personality.
Speak that chunk after moving."
  (interactive)
  (let ((personality (get-text-property (point) 'personality))
        (this-end (next-single-property-change (point) 'personality))
        (next-start nil))
    (cond
     ((and (< this-end (point-max))
           (setq next-start
                 (text-property-any  this-end (point-max)
                                     'personality personality)))
      (goto-char next-start)
      (forward-char 1)
      (emacspeak-speak-this-personality-chunk))
     (t (error "No more chunks with current personality.")))))

;;; this helper is here since text-property-any doesn't work
;;; backwards

(defsubst ems-backwards-text-property-any (max min property
                                               value)
  "Scan backwards from max till we find specified property
                                               setting.
Return buffer position or nil on failure."
  (let ((result nil)
        (start nil)
        (continue t))
    (save-excursion
      (while (and continue
                  (not (bobp)))
        (backward-char 1)
        (setq start (previous-single-property-change  (point) property))
        (if (null start)
            (setq continue nil)
          (setq continue
                (not (eq  value
                          (get-text-property start property)))))
        (or continue
            (setq result start)))
      result)))

;;;###autoload
(defun emacspeak-speak-previous-personality-chunk ()
  "Moves to the front of previous chunk having current personality.
Speak that chunk after moving."
  (interactive)
  (let ((personality (get-text-property (point) 'personality))
        (this-start (previous-single-property-change (point) 'personality))
        (next-end nil))
    (cond
     ((and (> this-start (point-min))
           (setq next-end
                 (ems-backwards-text-property-any  (1- this-start) (point-min)
                                                   'personality personality)))
      (goto-char next-end)
      (backward-char 1)
      (emacspeak-speak-this-personality-chunk))
     (t (error "No previous  chunks with current personality.")))))

(defun emacspeak-speak-face-interval-and-move ()
  "Speaks region delimited by text in current face, and moves past the chunk."
  (interactive)
  (let ((face (get-char-property (point) 'face))
        (start (point))
        (end nil))
;;; skip over opening delimiter
    (goto-char (next-single-char-property-change start 'face))
    (when (eobp) (error "End of buffer"))
    (setq end
          (or
           (text-property-any (point) (point-max)
                              'face face )
           (point-max)))
    (dtk-speak
     (buffer-substring start end))
    (goto-char end)
    (emacspeak-auditory-icon 'large-movement)))

;;}}}
;;{{{ speaking Face chunks

;;;###autoload
(defun emacspeak-speak-this-face-chunk ()
  "Speak chunk of text around point that has current face."
  (interactive)
  (let ((face (get-char-property (point) 'face))
        (start (previous-char-property-change (point)))
        (end (next-char-property-change  (point))))
    (emacspeak-speak-region
     (or start (point-min))
     (or end (point-max)))))

;;;###autoload
(defun emacspeak-speak-next-face-chunk ()
  "Moves to the front of next chunk having current face.
Speak that chunk after moving."
  (interactive)
  (let ((face (get-text-property (point) 'face))
        (this-end (next-single-property-change (point) 'face))
        (next-start nil))
    (cond
     ((and (< this-end (point-max))
           (setq next-start
                 (text-property-any  this-end (point-max)
                                     'face face)))
      (goto-char next-start)
      (forward-char 1)
      (emacspeak-speak-this-face-chunk))
     (t (message "No more chunks with current face.")))))

;;;###autoload
(defun emacspeak-speak-previous-face-chunk ()
  "Moves to the front of previous chunk having current face.
Speak that chunk after moving."
  (interactive)
  (let ((face (get-char-property (point) 'face))
        (this-start (previous-char-property-change (point)))
        (next-end nil))
    (cond
     ((and (> this-start (point-min))
           (setq next-end
                 (ems-backwards-text-property-any  (1- this-start) (point-min)
                                                   'face face)))
      (goto-char next-end)
      (backward-char 1)
      (emacspeak-speak-this-face-chunk))
     (t (error "No previous  chunks with current face.")))))

;;}}}
;;{{{  Execute command repeatedly, browse

;;;###autoload
(defun emacspeak-execute-repeatedly (command)
  "Execute COMMAND repeatedly."
  (interactive
   (list (read-command "Command to execute repeatedly:")))
  (let ((key "")
        (position (point ))
        (continue t )
        (message (format "Press space to execute %s again" command)))
    (while continue
      (call-interactively command )
      (cond
       ((= (point) position ) (setq continue nil))
       (t (setq position (point))
          (setq key
                (let ((dtk-stop-immediately nil ))
                  (read-key-sequence message )))
          (when(and (stringp key)
                    (not (=  32  (string-to-char key ))))
            (dtk-stop)
            (setq continue nil )))))
    (dtk-speak "Exited continuous mode ")))

;;;###autoload
(defun emacspeak-speak-continuously ()
  "Speak a buffer continuously.
First prompts using the minibuffer for the kind of action to
perform after speaking each chunk.  E.G.  speak a line at a time
etc.  Speaking commences at current buffer position.  Pressing
\\[keyboard-quit] breaks out, leaving point on last chunk that
was spoken.  Any other key continues to speak the buffer."
  (interactive)
  (let ((command
         (key-binding (read-key-sequence "Press key sequence to repeat: "))))
    (unless command (error "You specified an invalid key sequence.  " ))
    (emacspeak-execute-repeatedly command)))

;;;###autoload
(defun emacspeak-speak-browse-buffer (&optional browse)
  "Browse current buffer.
Default is to speak chunk having current personality.
Interactive prefix arg `browse'  repeatedly browses  through
  chunks having same personality as the current text chunk."
  (interactive "P")
  (cond
   (browse
    (emacspeak-execute-repeatedly
     'emacspeak-speak-next-personality-chunk))
   (t (emacspeak-speak-this-personality-chunk))))

(defvar emacspeak-read-line-by-line-quotient 10
  "Determines behavior of emacspeak-read-line-by-line.")

(defvar emacspeak-read-by-line-by-line-tick 1.0
  "Granularity of time for reading line-by-line.")

                                        ;(defun emacspeak-read-line-by-line ()
                                        ;  "Read line by line until interrupted"
                                        ;  (interactive)
                                        ;  (let ((count 0)
                                        ;        (line-length 0)
                                        ;        (continue t))
                                        ;    (while
                                        ;        (and continue
                                        ;             (not (eobp)))
                                        ;      (setq dtk-last-output "")
                                        ;      (call-interactively 'next-line)
                                        ;      (setq line-length (length  (thing-at-point 'line)))
                                        ;      (setq count 0)
                                        ;      (when (> line-length 0)
                                        ;        (while(and (< count
                                        ;                      (1+ (/ line-length emacspeak-read-line-by-line-quotient)))
                                        ;                   (setq continue
                                        ;                         (sit-for
                                        ;                          emacspeak-read-by-line-by-line-tick 0 nil ))
                                        ;                   (not (string-match  "done" dtk-last-output))
                                        ;                   (incf count))))))
                                        ;  (emacspeak-auditory-icon 'task-done)
                                        ;  (message "done moving "))

;;}}}
;;{{{  skimming

;;;###autoload
(defun emacspeak-speak-skim-paragraph()
  "Skim paragraph.
Skimming a paragraph results in the speech speeding up after
the first clause.
Speech is scaled by the value of dtk-speak-skim-scale"
  (interactive)
  (save-excursion
    (let ((inhibit-point-motion-hooks t)
          (start nil)
          (end nil))
      (forward-paragraph 1)
      (setq end (point))
      (backward-paragraph 1)
      (setq start (point))
      (dtk-speak (buffer-substring  start end )
                 'skim))))

;;;###autoload
(defun emacspeak-speak-skim-next-paragraph()
  "Skim next paragraph."
  (interactive)
  (forward-paragraph 1)
  (emacspeak-speak-skim-paragraph))

;;;###autoload
(defun emacspeak-speak-skim-buffer ()
  "Skim the current buffer  a paragraph at a time."
  (interactive)
  (emacspeak-execute-repeatedly 'emacspeak-speak-skim-next-paragraph))

;;}}}
;;{{{ comint

;;;###autoload
(defun emacspeak-completion-pick-completion ()
  "Pick completion and return safely where we came from."
  (interactive)
  (declare (special completion-reference-buffer))
  (let ((completion-ignore-case t))
    (choose-completion-string (emacspeak-get-current-completion) completion-reference-buffer))
  (emacspeak-auditory-icon 'select-object)
  (cond
   ((not (or
          (window-minibuffer-p)
          (one-window-p)
          (window-dedicated-p (selected-window))))
    (delete-window)
    (bury-buffer "*Completions*")
    (other-window 1))
   (t
    (kill-buffer "*Completions*")))
  (emacspeak-speak-line))

(defcustom emacspeak-comint-autospeak t
  "Says if comint output is automatically spoken.
You can use
  `emacspeak-toggle-comint-autospeak` bound to
  \\[emacspeak-toggle-comint-autospeak] to toggle this
setting."
  :group 'emacspeak-speak
  :type 'boolean)

(ems-generate-switcher ' emacspeak-toggle-comint-autospeak
                         'emacspeak-comint-autospeak
                         "Toggle state of Emacspeak comint autospeak.
When turned on, comint output is automatically spoken.  Turn this on if
you want your shell to speak its results.  Interactive
PREFIX arg means toggle the global default value, and then
set the current local value to the result.")

(defvar emacspeak-comint-output-monitor nil
  "Switch to monitor comint output.
When turned on,  comint output will be spoken even when the
buffer is not current or its window live.")

(make-variable-buffer-local
 'emacspeak-comint-output-monitor)

;;;###autoload
(ems-generate-switcher ' emacspeak-toggle-comint-output-monitor
                         'emacspeak-comint-output-monitor
                         "Toggle state of Emacspeak comint monitor.
When turned on, comint output is automatically spoken.  Turn this on if
you want your shell to speak its results.  Interactive
PREFIX arg means toggle the global default value, and then
set the current local value to the result.")

(defun emacspeak-comint-speech-setup ()
  "Set up splitting of speech into chunks in comint modes."
  (declare (special comint-mode-map
                    emacspeak-use-header-line))
  (when emacspeak-use-header-line
    (setq header-line-format
          '((:eval
             (format "%s  %s"
                     (abbreviate-file-name default-directory)
                     (propertize (buffer-name) 'personality voice-annotate))))))
  (dtk-set-punctuations 'all)
  (define-key comint-mode-map "\C-o" 'switch-to-completions)
  (emacspeak-pronounce-refresh-pronunciations))

(add-hook 'comint-mode-hook 'emacspeak-comint-speech-setup)
(defvar emacspeak-speak-comint-output nil
  "Temporarily set to T by command
emacspeak-speak-comint-send-input.")

;;;###autoload
(defun emacspeak-speak-comint-send-input ()
  "Causes output to be spoken i.e., as if comint autospeak were turned
on."
  (interactive)
  (declare (special emacspeak-speak-comint-output))
  (setq emacspeak-speak-comint-output t)
  (call-interactively 'comint-send-input)
  (emacspeak-auditory-icon 'select-object))

;;}}}
;;{{{   quiten messages

(defcustom emacspeak-speak-messages t
  "*Option indicating if messages are spoken.  If nil,
emacspeak will not speak messages as they are echoed to the
message area.  You can use command
`emacspeak-toggle-speak-messages' bound to
\\[emacspeak-toggle-speak-messages]."

  :group 'emacspeak-speak
  :type 'boolean)

(ems-generate-switcher 'emacspeak-toggle-speak-messages
                       'emacspeak-speak-messages
                       "Toggle the state of whether emacspeak echoes messages.")

;;}}}
;;{{{  Moving across fields:
;;; Fields are defined by property 'field

;;; helper function: speak a field
(defsubst  emacspeak-speak-field (start end )
  "Speaks field delimited by arguments START and END."
  (declare (special voice-annotate))
  (let ((header (or (get-text-property start  'field-name) "")))
    (dtk-speak
     (concat
      (progn (put-text-property 0 (length header )
                                'personality voice-annotate
                                header )
             header )
      " "
      (buffer-substring  start end)))))

(defun emacspeak-speak-current-field ()
  "Speak current field."
  (interactive)
  (emacspeak-speak-region (field-beginning)
                          (field-end)))

(defun emacspeak-speak-next-field ()
  "Move to and speak next field."
  (interactive)
  (declare (special inhibit-field-text-motion))
  (let((inhibit-field-text-motion t)
       (start nil ))
    (skip-syntax-forward "^ ")
    (skip-syntax-forward " ")
    (setq start (point ))
    (save-excursion
      (skip-syntax-forward "^ ")
      (emacspeak-speak-field start (point)))))

;;;###autoload
(defun emacspeak-speak-previous-field ()
  "Move to previous field and speak it."
  (interactive)
  (declare (special inhibit-field-text-motion))
  (let ((inhibit-field-text-motion t)
        (start nil ))
    (skip-syntax-backward " ")
    (setq start (point ))
    (skip-syntax-backward "^ ")
    (emacspeak-speak-field (point ) start)))

(defun emacspeak-speak-current-column ()
  "Speak the current column."
  (interactive)
  (message "Point at column %d" (current-column )))

(defun emacspeak-speak-current-percentage ()
  "Announce the percentage into the current buffer."
  (interactive)
  (message "Point is  %d%% into  the current buffer"
           (emacspeak-get-current-percentage-into-buffer )))

;;}}}
;;{{{  Speak the last message again:

(defcustom emacspeak-speak-message-again-should-copy-to-kill-ring t
  "If set, asking for last message will copy it to the kill ring."
  :type 'boolean
  :group 'emacspeak-speak)

;;;###autoload
(defun emacspeak-speak-message-again (&optional from-message-cache)
  "Speak the last message from Emacs once again.
The message is also placed in the kill ring for convenient yanking
if `emacspeak-speak-message-again-should-copy-to-kill-ring' is set."
  (interactive "P")
  (declare (special emacspeak-last-message
                    emacspeak-speak-message-again-should-copy-to-kill-ring))
  (cond
   (from-message-cache
    (dtk-speak   emacspeak-last-message)
    (when (and (ems-interactive-p )
               emacspeak-speak-message-again-should-copy-to-kill-ring)
      (kill-new emacspeak-last-message)))
   (t
    (save-current-buffer
      (set-buffer "*Messages*")
      (goto-char (point-max))
      (skip-syntax-backward " ")
      (emacspeak-speak-line)
      (when (and (ems-interactive-p )
                 emacspeak-speak-message-again-should-copy-to-kill-ring)
        (kill-new
         (buffer-substring (line-beginning-position)
                           (line-end-position))))))))

(defun emacspeak-announce (announcement)
  "Speak the ANNOUNCEMENT, if possible.
Otherwise just display a message."
  (message announcement))

;;}}}
;;{{{  Using emacs's windows usefully:

;;Return current window contents
(defsubst emacspeak-get-window-contents ()
  "Return window contents."
  (let ((start nil))
    (save-excursion
      (move-to-window-line 0)
      (setq start (point))
      (move-to-window-line -1)
      (end-of-line)
      (buffer-substring start (point)))))

;;;###autoload
(defun emacspeak-speak-window-information ()
  "Speaks information about current window."
  (interactive)
  (message "Current window has %s lines and %s columns with
top left %s %s "
           (window-height)
           (window-width)
           (first (window-edges))
           (second (window-edges))))

;;;###autoload
(defun emacspeak-speak-current-window ()
  "Speak contents of current window.
Speaks entire window irrespective of point."
  (interactive)
  (emacspeak-speak-region (window-start) (window-end )))

;;;###autoload
(defun emacspeak-speak-other-window (&optional arg)
  "Speak contents of `other' window.
Speaks entire window irrespective of point.
Semantics  of `other' is the same as for the builtin Emacs command
`other-window'.
Optional argument ARG  specifies `other' window to speak."
  (interactive "nSpeak window")
  (save-excursion
    (save-window-excursion
      (other-window arg )
      (save-current-buffer
        (set-buffer (window-buffer))
        (emacspeak-speak-region
         (max (point-min) (window-start) )
         (min (point-max)(window-end )))))))

;;;###autoload
(defun emacspeak-speak-next-window ()
  "Speak the next window."
  (interactive)
  (emacspeak-speak-other-window 1 ))

;;;###autoload
(defun emacspeak-speak-previous-window ()
  "Speak the previous window."
  (interactive)
  (emacspeak-speak-other-window -1 ))

;;;###autoload
(defun  emacspeak-owindow-scroll-up ()
  "Scroll up the window that command `other-window' would move to.
Speak the window contents after scrolling."
  (interactive)
  (let ((window (selected-window)))
    (other-window 1)
    (call-interactively 'scroll-up)
    (select-window window)))

;;;###autoload
(defun  emacspeak-owindow-scroll-down ()
  "Scroll down  the window that command `other-window' would move to.
Speak the window contents after scrolling."
  (interactive)
  (let ((window (selected-window)))
    (other-window 1)
    (call-interactively 'scroll-down)
    (select-window window)))

;;;###autoload
(defun emacspeak-owindow-next-line (count)
  "Move to the next line in the other window and speak it.
Numeric prefix arg COUNT can specify number of lines to move."
  (interactive "p")
  (setq count (or count 1 ))
  (let  ((residue nil )
         )
    (save-current-buffer
      (set-buffer (window-buffer (next-window )))
      (end-of-line)
      (setq residue (forward-line count))
      (cond
       ((> residue 0) (message "At bottom of other window "))
       (t (set-window-point (get-buffer-window (current-buffer ))
                            (point))
          (emacspeak-speak-line ))))))

;;;###autoload
(defun emacspeak-owindow-previous-line (count)
  "Move to the next line in the other window and speak it.
Numeric prefix arg COUNT specifies number of lines to move."
  (interactive "p")
  (setq count (or count 1 ))
  (let  ((residue nil ))
    (save-current-buffer
      (set-buffer (window-buffer (next-window )))
      (end-of-line)
      (setq residue (forward-line (- count)))
      (cond
       ((> 0 residue) (message "At top of other window "))
       (t (set-window-point (get-buffer-window (current-buffer ))
                            (point))
          (emacspeak-speak-line ))))))

;;;###autoload
(defun emacspeak-owindow-speak-line ()
  "Speak the current line in the other window."
  (interactive)
  (save-current-buffer
    (set-buffer (window-buffer (next-window )))
    (goto-char (window-point ))
    (emacspeak-speak-line)))

;;;###autoload
(defun emacspeak-speak-predefined-window (&optional arg)
  "Speak one of the first 10 windows on the screen.
Speaks entire window irrespective of point.
In general, you'll never have Emacs split the screen into more than
two or three.
Argument ARG determines the 'other' window to speak.
Semantics  of `other' is the same as for the builtin Emacs command
`other-window'."
  (interactive "P")
  (let* ((window-size-change-functions nil)
         (window
          (cond
           ((not (ems-interactive-p )) arg)
           (t
            (condition-case nil
                (read (format "%c" last-input-event ))
              (error nil ))))))
    (or (numberp window)
        (setq window
              (read-minibuffer
               "Window   between 1 and 9 to speak")))
    (setq window (1- window))
    (save-excursion
      (save-window-excursion
        (other-window window )
        (emacspeak-speak-region (window-start) (window-end ))))))

;;}}}
;;{{{  Intelligent interactive commands for reading:

;;; Prompt the user if asked to prompt.
;;; Prompt is:
;;; press 'b' for beginning of unit,
;;; 'r' for rest of unit,
;;; any other key for entire unit
;;; returns 1, -1, or nil accordingly.
;;; If prompt is nil, does not prompt: just gets the input

(defun emacspeak-ask-how-to-speak (unit-name prompt)
  "Argument UNIT-NAME specifies kind of unit that is being spoken.
Argument PROMPT specifies the prompt to display."
  (if prompt
      (message
       (format "Press s to speak start of %s, r for rest of  %s. \
 Any  key for entire %s "
               unit-name unit-name unit-name )))
  (let ((char (read-char )))
    (cond
     ((= char ?s) -1)
     ((= char ?r) 1)
     (t nil ))))

;;;###autoload
(defun emacspeak-speak-buffer-interactively ()
  "Speak the start of, rest of, or the entire buffer.
's' to speak the start.
'r' to speak the rest.
any other key to speak entire buffer."
  (interactive)
  (emacspeak-speak-buffer
   (emacspeak-ask-how-to-speak "buffer" (sit-for 1))))

;;;###autoload
(defun emacspeak-speak-help-interactively ()
  "Speak the start of, rest of, or the entire help.
's' to speak the start.
'r' to speak the rest.
any other key to speak entire help."
  (interactive)
  (emacspeak-speak-help
   (emacspeak-ask-how-to-speak "help" (sit-for 1))))

;;;###autoload
(defun emacspeak-speak-line-interactively ()
  "Speak the start of, rest of, or the entire line.
's' to speak the start.
'r' to speak the rest.
any other key to speak entire line."
  (interactive)
  (emacspeak-speak-line
   (emacspeak-ask-how-to-speak "line" (sit-for 1))))

;;;###autoload
(defun emacspeak-speak-paragraph-interactively ()
  "Speak the start of, rest of, or the entire paragraph.
's' to speak the start.
'r' to speak the rest.
any other key to speak entire paragraph."
  (interactive)
  (emacspeak-speak-paragraph
   (emacspeak-ask-how-to-speak "paragraph" (sit-for 1))))

;;;###autoload
(defun emacspeak-speak-page-interactively ()
  "Speak the start of, rest of, or the entire page.
's' to speak the start.
'r' to speak the rest.
any other key to speak entire page."
  (interactive)
  (emacspeak-speak-page
   (emacspeak-ask-how-to-speak "page" (sit-for 1))))

;;;###autoload
(defun emacspeak-speak-word-interactively ()
  "Speak the start of, rest of, or the entire word.
's' to speak the start.
'r' to speak the rest.
any other key to speak entire word."
  (interactive)
  (emacspeak-speak-word
   (emacspeak-ask-how-to-speak "word" (sit-for 1))))

;;;###autoload
(defun emacspeak-speak-sexp-interactively ()
  "Speak the start of, rest of, or the entire sexp.
's' to speak the start.
'r' to speak the rest.
any other key to speak entire sexp."
  (interactive)
  (emacspeak-speak-sexp
   (emacspeak-ask-how-to-speak "sexp" (sit-for 1))))

;;}}}
;;{{{  emacs rectangles and regions:

(eval-when (compile) (require 'rect))
;;; These help you listen to columns of text. Useful for tabulated data
;;;###autoload
(defun emacspeak-speak-rectangle ( start end )
  "Speak a rectangle of text.
Rectangle is delimited by point and mark.
When call from a program,
arguments specify the START and END of the rectangle."
  (interactive  "r")
  (require 'rect)
  (dtk-speak-list (extract-rectangle start end )))

;;; helper function: emacspeak-put-personality
;;; sets property 'personality to personality
(defsubst emacspeak-put-personality (start end personality )
  "Apply specified personality to region delimited by START and END.
Argument PERSONALITY gives the value for property personality."
  (put-text-property start end 'personality personality ))

;;; Compute table of possible voices to use in completing-read
;;; We rely on dectalk-voice-table as our default voice table.
;;; Names defined in this --- and other voice tables --- are
;;; generic --and  not device specific.
;;;

(defsubst  emacspeak-possible-voices ()
  "Return possible voices."
  (declare (special dectalk-voice-table ))
  (loop for key being the hash-keys of dectalk-voice-table
        collect  (cons
                  (symbol-name key)
                  (symbol-name key))))

;;;###autoload
(defun emacspeak-voiceify-rectangle (start end &optional personality )
  "Voicify the current rectangle.
When calling from a program,arguments are
START END personality
Prompts for PERSONALITY  with completion when called interactively."
  (interactive "r")
  (require 'rect)
  (require 'emacspeak-personality )
  (let ((personality-table (emacspeak-possible-voices )))
    (when (ems-interactive-p )
      (setq personality
            (read
             (completing-read "Use personality: "
                              personality-table nil t ))))
    (with-silent-modifications
      (operate-on-rectangle
       (function (lambda ( start-seg begextra endextra )
                   (emacspeak-put-personality start-seg  (point) personality )))
       start end  nil))))

;;;###autoload
(defun emacspeak-voiceify-region (start end &optional personality )
  "Voicify the current region.
When calling from a program,arguments are
START END personality.
Prompts for PERSONALITY  with completion when called interactively."
  (interactive "r")
  (require 'emacspeak-personality )
  (let ((personality-table (emacspeak-possible-voices )))
    (when (ems-interactive-p )
      (setq personality
            (read
             (completing-read "Use personality: "
                              personality-table nil t ))))
    (put-text-property start end 'personality personality )))

(defun emacspeak-put-text-property-on-rectangle   (start end prop value )
  "Set property to specified value for each line in the rectangle.
Argument START and END specify the rectangle.
Argument PROP specifies the property and VALUE gives the
value to apply."
  (require 'rect)
  (operate-on-rectangle
   (function (lambda ( start-seg begextra endextra )
               (put-text-property  start-seg (point)    prop value  )))
   start end  nil ))

;;}}}
;;{{{  Matching delimiters:

;;; A modified blink-matching-open that always displays the matching line
;;; in the minibuffer so emacspeak can speak it.
;;;Helper: emacspeak-speak-blinkpos-message

(defsubst emacspeak-speak-blinkpos-message(blinkpos)
  "Speak message about matching blinkpos."
  (message "Matches %s"
           ;; Show what precedes the open in its line, if anything.
           (if (save-excursion
                 (skip-chars-backward " \t")
                 (not (bolp)))
               (buffer-substring (line-beginning-position)
                                 (1+ blinkpos))
             ;; Show what follows the open in its line, if anything.
             (if (save-excursion
                   (forward-char 1)
                   (skip-chars-forward " \t")
                   (not (eolp)))
                 (buffer-substring blinkpos
                                   (progn (end-of-line) (point)))
               ;; Otherwise show the previous nonblank line.
               (concat
                (buffer-substring (progn
                                    (backward-char 1)
                                    (skip-chars-backward "\n \t")
                                    (line-beginning-position))
                                  (progn (end-of-line)
                                         (skip-chars-backward " \t")
                                         (point)))
                ;; Replace the newline and other whitespace with `...'.
                "..."
                (buffer-substring blinkpos (1+
                                            blinkpos)))))))

;;; The only change to emacs' default blink-matching-paren is the
;;; addition of the call to helper emacspeak-speak-blinkpos-message

(defun emacspeak-blink-matching-open ()
  "Move cursor momentarily to the beginning of the sexp before point.
Also display match context in minibuffer."
  (interactive)
  (when (and (> (point) (point-min))
             blink-matching-paren
             ;; Verify an even number of quoting characters precede the close.
             (= 1 (logand 1 (- (point)
                               (save-excursion
                                 (forward-char -1)
                                 (skip-syntax-backward "/\\")
                                 (point))))))
    (let* ((oldpos (point))
           (blink-matching-delay 5)
           blinkpos
           message-log-max  ; Don't log messages about paren matching.
           matching-paren
           open-paren-line-string)
      (save-excursion
        (save-restriction
          (if blink-matching-paren-distance
              (narrow-to-region (max (minibuffer-prompt-end)
                                     (- (point) blink-matching-paren-distance))
                                oldpos))
          (condition-case ()
              (let ((parse-sexp-ignore-comments
                     (and parse-sexp-ignore-comments
                          (not blink-matching-paren-dont-ignore-comments))))
                (setq blinkpos (scan-sexps oldpos -1)))
            (error nil)))
        (and blinkpos
             ;; Not syntax '$'.
             (not (eq (syntax-class (syntax-after blinkpos)) 8))
             (setq matching-paren
                   (let ((syntax (syntax-after blinkpos)))
                     (and (consp syntax)
                          (eq (syntax-class syntax) 4)
                          (cdr syntax)))))
        (cond
         ((not (or (eq matching-paren (char-before oldpos))
                   ;; The cdr might hold a new paren-class info rather than
                   ;; a matching-char info, in which case the two CDRs
                   ;; should match.
                   (eq matching-paren (cdr (syntax-after (1- oldpos))))))
          (message "Mismatched parentheses"))
         ((not blinkpos)
          (if (not blink-matching-paren-distance)
              (message "Unmatched parenthesis")))
         ((pos-visible-in-window-p blinkpos)
          ;; Matching open within window, temporarily move to blinkpos but only
          ;; if `blink-matching-paren-on-screen' is non-nil.
          (and blink-matching-paren-on-screen
               (not show-paren-mode)
               (save-excursion
                 (goto-char blinkpos)
                 (emacspeak-speak-blinkpos-message blinkpos)
                 (sit-for blink-matching-delay))))
         (t
          (save-excursion
            (goto-char blinkpos)
            (setq open-paren-line-string
                  ;; Show what precedes the open in its line, if anything.
                  (if (save-excursion
                        (skip-chars-backward " \t")
                        (not (bolp)))
                      (buffer-substring (line-beginning-position)
                                        (1+ blinkpos))
                    ;; Show what follows the open in its line, if anything.
                    (if (save-excursion
                          (forward-char 1)
                          (skip-chars-forward " \t")
                          (not (eolp)))
                        (buffer-substring blinkpos
                                          (line-end-position))
                      ;; Otherwise show the previous nonblank line,
                      ;; if there is one.
                      (if (save-excursion
                            (skip-chars-backward "\n \t")
                            (not (bobp)))
                          (concat
                           (buffer-substring (progn
                                               (skip-chars-backward "\n \t")
                                               (line-beginning-position))
                                             (progn (end-of-line)
                                                    (skip-chars-backward " \t")
                                                    (point)))
                           ;; Replace the newline and other whitespace with `...'.
                           "..."
                           (buffer-substring blinkpos (1+ blinkpos)))
                        ;; There is nothing to show except the char itself.
                        (buffer-substring blinkpos (1+ blinkpos)))))))
          (message "Matches %s"
                   (substring-no-properties
                    open-paren-line-string))
          (sit-for blink-matching-delay)))))))

(defun  emacspeak-use-customized-blink-paren ()
  "A customized blink-paren to speak  matching opening paren.
We need to call this in case Emacs is anal and loads its own
builtin blink-paren function which does not talk."
  (interactive)
  (fset 'blink-matching-open (symbol-function 'emacspeak-blink-matching-open))
  (and (ems-interactive-p )
       (message "Using customized blink-paren function provided by Emacspeak.")))

;;}}}
;;{{{  Auxillary functions:

(defsubst emacspeak-kill-buffer-carefully (buffer)
  "Kill BUFFER BUF if it exists."
  (and buffer
       (get-buffer buffer)
       (buffer-name (get-buffer buffer ))
       (kill-buffer buffer)))

(defsubst emacspeak-overlay-get-text (o)
  "Return text under overlay OVERLAY.
Argument O specifies overlay."
  (save-current-buffer
    (set-buffer (overlay-buffer o ))
    (buffer-substring (overlay-start o) (overlay-end o ))))

;;}}}
;;{{{ Speaking spaces

;;;###autoload
(defun emacspeak-speak-spaces-at-point ()
  "Speak the white space at point."
  (interactive)
  (cond
   ((not (= 32 (char-syntax (following-char ))))
    (message "Not on white space"))
   (t
    (let ((orig (point))
          (start (save-excursion
                   (skip-syntax-backward " ")
                   (point)))
          (end (save-excursion
                 (skip-syntax-forward " ")
                 (point))))
      (message "Space %s of %s"
               (1+ (- orig start)) (- end start ))))))

;;}}}
;;{{{  translate faces to voices

(defun voice-lock-voiceify-faces ()
  "Map faces to personalities."
  (save-excursion
    (goto-char (point-min))
    (let ((inhibit-read-only t )
          (face nil )
          (start (point)))
      (unwind-protect
          (while (not (eobp))
            (setq face (get-text-property (point) 'face ))
            (goto-char
             (or (next-single-property-change (point) 'face )
                 (point-max)))
            (put-text-property start  (point)
                               'personality
                               (if (listp face)
                                   (car face)
                                 face ))
            (setq start (point)))
        (setq inhibit-read-only nil)))))

;;}}}
;;{{{  completion helpers

;;{{{ switching to completions window from minibuffer:

(defsubst emacspeak-get-minibuffer-contents ()
  "Return contents of the minibuffer."
  (save-current-buffer
    (set-buffer (window-buffer (minibuffer-window)))
    (minibuffer-contents-no-properties)))

;;; Make all occurrences of string inaudible
(defsubst emacspeak-make-string-inaudible(string)
  (unless (string-match "^ *$" string)
    (with-silent-modifications
      (save-excursion
        (goto-char (point-min))
        (save-match-data
          (with-silent-modifications
            (while (search-forward string nil t)
              (put-text-property (match-beginning 0)
                                 (match-end 0)
                                 'personality 'inaudible))))))))

;;;###autoload
(defun emacspeak-switch-to-reference-buffer ()
  "Switch back to buffer that generated completions."
  (interactive)
  (declare (special completion-reference-buffer))
  (if completion-reference-buffer
      (switch-to-buffer completion-reference-buffer)
    (error "Reference buffer not found."))
  (when (ems-interactive-p )
    (emacspeak-speak-line)
    (emacspeak-auditory-icon 'select-object)))

;;;###autoload
(defun emacspeak-completions-move-to-completion-group()
  "Move to group of choices beginning with character last
typed. If no such group exists, then we try to search for that
char, or dont move. "
  (interactive)
  (declare (special last-input-event))
  (let ((pattern
         (format
          "[ \t\n]%s%c"
          (or (emacspeak-get-minibuffer-contents) "")
          last-input-event))
        (input (format "%c" last-input-event))
        (case-fold-search t))
    (when (or (re-search-forward pattern nil t)
              (re-search-backward pattern nil t)
              (search-forward input nil t)
              (search-backward input nil t))
      (skip-syntax-forward " ")
      (emacspeak-auditory-icon 'search-hit))
    (dtk-speak (emacspeak-get-current-completion ))))

(defun emacspeak-completion-setup-hook ()
  "Set things up for emacspeak."
  (with-current-buffer standard-output
    (goto-char (point-min))
    (emacspeak-make-string-inaudible (emacspeak-get-minibuffer-contents))
    (emacspeak-auditory-icon 'help)))

(add-hook 'completion-setup-hook 'emacspeak-completion-setup-hook)

(declaim (special completion-list-mode-map))  
(define-key completion-list-mode-map "\C-o" 'emacspeak-switch-to-reference-buffer)
(define-key completion-list-mode-map " "'next-completion)
(define-key completion-list-mode-map "\C-m"  'choose-completion)
(define-key completion-list-mode-map "\M-\C-m" 'emacspeak-completion-pick-completion)
(let ((chars
       "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"))
  (loop for char across chars
        do
        (define-key completion-list-mode-map
          (format "%c" char)
          'emacspeak-completions-move-to-completion-group)))

;;}}}

;;}}}
;;{{{ mark convenience commands

(defsubst emacspeak-mark-speak-mark-line()
  (declare (special voice-animate))
  (emacspeak-auditory-icon 'mark-object )
  (ems-set-personality-temporarily (point) (1+ (point))
                                   voice-animate
                                   (emacspeak-speak-line)))

;;;###autoload

(defalias 'emacspeak-mark-forward-mark 'pop-to-mark-command)
;;;###autoload
(defun emacspeak-mark-backward-mark ()
  "Cycle backward through the mark ring."
  (interactive)
  (declare (special mark-ring))
  (unless mark-ring (error "Mark ring is empty."))
  (let ((target  (elt  mark-ring (1- (length mark-ring)))))
    (when target
      (setq mark-ring
            (cons (copy-marker (mark-marker))
                  (nbutlast mark-ring 1)))
      (set-marker (mark-marker)  (point) (current-buffer))
      (goto-char (marker-position target))
      (move-marker target nil)
      (when (ems-interactive-p )
        (emacspeak-mark-speak-mark-line)))))

;;}}}
;;{{{ customize emacspeak

;;}}}
;;{{{ speaking an extent of text delimited by specified char

;;;###autoload
(defun emacspeak-speak-and-skip-extent-upto-char (char)
  "Search forward from point until we hit char.
Speak text between point and the char we hit."
  (interactive "c")
  (let ((start (point))
        (goal nil))
    (save-excursion
      (cond
       ((search-forward (format "%c" char)
                        (point-max)
                        'no-error)
        (setq goal (point))
        (emacspeak-speak-region start goal)
        (emacspeak-auditory-icon 'select-object))
       (t (error "Could not find %c" char))))
    (when goal (goto-char goal))))

;;;###autoload
(defun emacspeak-speak-and-skip-extent-upto-this-char ()
  "Speak extent delimited by point and last character typed."
  (interactive)
  (declare (special last-input-event))
  (emacspeak-speak-and-skip-extent-upto-char last-input-event))

;;}}}
;;{{{  speak message at time
;;;###autoload
(defun emacspeak-speak-message-at-time (time message)
  "Set up ring-at-time to speak message at specified time.
Provides simple stop watch functionality in addition to other things.
See documentation for command run-at-time for details on time-spec."
  (interactive
   (list
    (read-from-minibuffer "Time specification:  ")
    (read-from-minibuffer "Message: ")))
  (run-at-time time nil
               #'(lambda (m)
                   (message m)
                   (emacspeak-auditory-icon 'alarm))
               message))

;;}}}
;;{{{ Directory specific settings
(defcustom  emacspeak-speak-load-directory-settings-quietly t
  "*User option that affects loading of directory specific settings.
If set to T,Emacspeak will not prompt before loading
directory specific settings."
  :group 'emacspeak-speak
  :type 'boolean)

(defcustom emacspeak-speak-directory-settings
  ".espeak.el"
  "*Name of file that holds directory specific settings."
  :group 'emacspeak-speak
  :type 'string)

(defsubst emacspeak-speak-root-dir-p (dir)
  "Check if we are at the root of the filesystem."
  (let ((parent (expand-file-name  "../" dir)))
    (or (or (not (file-readable-p dir))
            (not (file-readable-p parent)))
        (and
         (string-equal (file-truename dir) "/")
         (string-equal (file-truename parent) "/")))))

(defun emacspeak-speak-get-directory-settings (dir)
  "Finds the next directory settings  file upwards in the directory tree
from DIR. Returns nil if it cannot find a settings file in DIR
or an ascendant directory."
  (declare (special emacspeak-speak-directory-settings
                    default-directory))
  (let ((file (find emacspeak-speak-directory-settings
                    (directory-files dir)
                    :test 'string-equal)))
    (cond
     (file (expand-file-name file dir))
     ((not (emacspeak-speak-root-dir-p dir))
      (emacspeak-speak-get-directory-settings (expand-file-name ".." dir)))
     (t nil))))

;;;###autoload
(defun emacspeak-speak-load-directory-settings (&optional directory)
  "Load a directory specific Emacspeak settings file.
This is typically used to load up settings that are specific to
an electronic book consisting of many files in the same
directory."
  (interactive "DDirectory:")
  (or directory
      (setq directory default-directory))
  (let ((settings (emacspeak-speak-get-directory-settings directory)))
    (when (and settings
               (file-exists-p  settings)
               (or emacspeak-speak-load-directory-settings-quietly
                   (y-or-n-p "Load directory settings? ")
                   "Load  directory specific Emacspeak
settings? "))
      (condition-case nil
          (load-file settings)
        (error (message "Error loading settings %s" settings))))))

;;}}}
;;{{{ silence:
;;;###autoload
(defcustom emacspeak-silence-hook nil
  "Functions run after emacspeak-silence is called."
  :type '(repeat  function)
  :group 'emacspeak)

;;;###autoload
(defun emacspeak-silence()
  "Silence is golden. Stop speech, and pause/resume any media
streams.
Runs `emacspeak-silence-hook' which can be used to configure
which media players get silenced or paused/resumed."
  (interactive)
  (declare (special  emacspeak-silence-hook))
  (dtk-stop)
  (run-hooks 'emacspeak-silence-hook))

;;}}}
;;{{{ Search 

(defcustom emacspeak-search 'emacspeak-websearch-google
  "Default search engine."
  :type 'function
  :group 'emacspeak)

(defun emacspeak-search ()
  "Call search defined in \\[emacspeak-search]."
  (interactive)
  (declare (special emacspeak-search))
  (call-interactively emacspeak-search))
;;}}}
;;{{{ Network interface utils:

(defvar emacspeak-speak-network-interfaces-list
  (when (boundp 'network-interface-list)
    (mapcar 'car (network-interface-list)))
  "Used when prompting for an interface to query.")

(defsubst ems-get-ip-address  (&optional dev)
  "get the IP-address for device DEV "
  (format-network-address
   (car
    (network-interface-info
     (or  dev
          (completing-read "Device: "
                           emacspeak-speak-network-interfaces-list)))) t))

(defsubst ems-get-active-network-interfaces  ()
  "Return  names of active network interfaces."
  (when (fboundp 'network-interface-list)
    (mapconcat #'car (network-interface-list) " ")))

;;}}}
;;{{{ Show active network interfaces

;;;###autoload
(defun emacspeak-speak-hostname ()
  "Speak host name."
  (interactive)
  (message (system-name)))

;;;###autoload
(defun emacspeak-speak-show-active-network-interfaces (&optional address)
  "Shows all active network interfaces in the echo area.
With interactive prefix argument ADDRESS it prompts for a
specific interface and shows its address. The address is
also copied to the kill ring for convenient yanking."
  (interactive "P")
  (kill-new
   (message
    (if address
        (ems-get-ip-address)
      (ems-get-active-network-interfaces)))))

;;}}}
(provide 'emacspeak-speak )
;;{{{ end of file

;;; local variables:
;;; folded-file: t
;;; byte-compile-dynamic: nil
;;; end:

;;}}}
