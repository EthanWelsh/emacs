;;; emacspeak-info.el --- Speech enable Info -- Emacs' online documentation viewer
;;; $Id: emacspeak-info.el 8577 2013-11-25 16:34:15Z tv.raman.tv $
;;; $Author: tv.raman.tv $
;;; Description:  Module for customizing Emacs info
;;; Keywords:emacspeak, audio interface to emacs
;;{{{  LCD Archive entry:

;;; LCD Archive Entry:
;;; emacspeak| T. V. Raman |raman@cs.cornell.edu
;;; A speech interface to Emacs |
;;; $Date: 2007-08-25 18:28:19 -0700 (Sat, 25 Aug 2007) $ |
;;;  $Revision: 4558 $ |
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
;;{{{ Introduction:

;;; This module extends and customizes the Emacs info reader.

;;}}}
;;{{{ requires
(require 'emacspeak-preamble)
(require 'info)
;;}}}
;;{{{  Variables:

(defvar Info-voiceify t
  "*Non-nil enables highlighting and voices in Info nodes.")

(defvar Info-voiceify-maximum-menu-size 30000
  "*Maximum size of menu to voiceify if `Info-voiceify' is non-nil.")

;;}}}
;;{{{  Voices
(voice-setup-add-map
 '(
   (info-index-match 'voice-bolden-medium)
   (info-title-1 voice-bolden-extra)
   (info-title-2 voice-bolden-medium)
   (info-title-3 voice-bolden)
   (info-title-4 voice-lighten)
   (info-header-node voice-smoothen)
   (info-header-xref voice-brighten)
   (info-menu-5 voice-lighten)
   (info-menu-header voice-bolden-medium)
   (info-node voice-monotone)
   (info-xref voice-animate-extra)
   (info-menu-star voice-brighten)
   (info-xref-visited voice-animate-medium)
   ))

;;}}}
;;{{{ advice

(defcustom  emacspeak-info-select-node-speak-chunk 'screenfull
  "*Specifies how much of the selected node gets spoken.
Possible values are:
screenfull  -- speak the displayed screen
node -- speak the entire node."
  :type '(menu-choice
          (const :tag "First screenfull" screenfull)
          (const :tag "Entire node" node))
  :group 'emacspeak-info)

(defsubst emacspeak-info-speak-current-window ()
  "Speak current window in info buffer."
  (let ((start  (point ))
        (window (get-buffer-window (current-buffer ))))
    (save-excursion
      (forward-line (window-height window))
      (emacspeak-speak-region start (point )))))

(defun emacspeak-info-visit-node()
  "Apply requested action upon visiting a node."
  (declare (special emacspeak-info-select-node-speak-chunk))
  (let ((dtk-stop-immediately t ))
    (emacspeak-auditory-icon 'select-object)
    (cond
     ((eq emacspeak-info-select-node-speak-chunk
          'screenfull)
      (emacspeak-info-speak-current-window))
     ((eq emacspeak-info-select-node-speak-chunk 'node)
      (emacspeak-speak-buffer ))
     (t (emacspeak-speak-line)))))
(loop for f in
      '(info-display-manual Info-select-node)
      do
      (eval
       `(defadvice ,f (after emacspeak pre act)
          " Speak the selected node based on setting of
emacspeak-info-select-node-speak-chunk"
          (emacspeak-info-visit-node))))

(defadvice info (after emacspeak pre act)
  "Cue user that info is up."
  (when (ems-interactive-p )
    (emacspeak-auditory-icon 'help)
    (emacspeak-speak-line)))

(defadvice Info-scroll-up (after emacspeak pre act)
  "Speak the screenful."
  (when (ems-interactive-p )
    (emacspeak-auditory-icon 'scroll)
    (let ((start  (point ))
          (window (get-buffer-window (current-buffer ))))
      (save-excursion
        (forward-line (window-height window))
        (emacspeak-speak-region start (point ))))))

(defadvice Info-scroll-down (after emacspeak pre act)
  "Speak the screenful."
  (when (ems-interactive-p )
    (emacspeak-auditory-icon 'scroll)
    (let ((start  (point ))
          (window (get-buffer-window (current-buffer ))))
      (save-excursion
        (forward-line (window-height window))
        (emacspeak-speak-region start (point ))))))

(defadvice Info-exit (after emacspeak pre act)
  "Play an auditory icon to close info,
and then cue the next selected buffer."
  (when (ems-interactive-p  )
    (dtk-stop)
    (emacspeak-auditory-icon 'close-object)
    (emacspeak-speak-mode-line)))

(defadvice Info-next-reference (after emacspeak pre act)
  "Speak the line. "
  (when (ems-interactive-p )
    (emacspeak-speak-line)))

(defadvice Info-prev-reference (after emacspeak pre act)
  "Speak the line. "
  (when (ems-interactive-p )
    (emacspeak-speak-line)))

;;}}}
;;{{{ Speak header line if hidden

(defun emacspeak-info-speak-header ()
  "Speak info header line."
  (interactive)
  (declare (special Info-use-header-line
                    Info-header-line))
  (let (cond
        ((and (boundp 'Info-use-header-line)
              (boundp 'Info-header-line)
              Info-header-line)
         (dtk-speak Info-header-line))
        (t (save-excursion
             (goto-char (point-min))
             (emacspeak-speak-line))))))

;;}}}
;;{{{  Emacs 21

;;}}}
;;{{{ keymaps
(declaim (special Info-mode-map))
(define-key Info-mode-map "T" 'emacspeak-info-speak-header)
(define-key Info-mode-map "'" 'emacspeak-speak-rest-of-buffer)
;;}}}
;;{{{ info wizard
;;;###autoload
(defun emacspeak-info-wizard (node-spec )
  "Read a node spec from the minibuffer and launch
Info-goto-node.
See documentation for command `Info-goto-node' for details on
node-spec."
  (interactive
   (list
    (read-from-minibuffer "Node: "
                          "(")))
  (Info-goto-node node-spec)
  (emacspeak-info-visit-node))

;;}}}

(provide  'emacspeak-info)
;;{{{  emacs local variables

;;; local variables:
;;; folded-file: t
;;; byte-compile-dynamic: nil
;;; end:

;;}}}
