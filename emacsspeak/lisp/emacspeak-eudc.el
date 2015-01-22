;;; emacspeak-eudc.el --- Speech enable  directory client 
;;; $Id: emacspeak-eudc.el 8574 2013-11-24 02:01:07Z tv.raman.tv $
;;; $Author: tv.raman.tv $
;;; Description:   extension to speech enable universal directory client 
;;; Keywords: Emacspeak, Audio Desktop
;;{{{  LCD Archive entry:

;;; LCD Archive Entry:
;;; emacspeak| T. V. Raman |raman@cs.cornell.edu
;;; A speech interface to Emacs |
;;; $Date: 2007-08-25 18:28:19 -0700 (Sat, 25 Aug 2007) $ |
;;;  $Revision: 4532 $ |
;;; Location undetermined
;;;

;;}}}
;;{{{  Copyright:

;;; Copyright (C) 1995 -- 2011, T. V. Raman<raman@cs.cornell.edu>
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

;;{{{ required modules
(require 'emacspeak-preamble)              
;;}}}
;;{{{  Introduction:

;;; Commentary:

;;; EUDC --Emacs Universal Directory Client 
;;; provides a unified interface to directory servers
;;; e.g. ldap servers
;;; this module speech enables eudc 

;;; Code:

;;}}}
;;{{{ speech enable interactive commands 

(defadvice eudc-move-to-next-record (after emacspeak pre act comp)
  "Provide auditory feedback. "
  (when (ems-interactive-p )
    (emacspeak-auditory-icon 'select-object)
    (emacspeak-speak-line)))

(defadvice eudc-move-to-previous-record (after emacspeak pre act
                                               comp)
  "Provide auditory feedback. "
  (when (ems-interactive-p )
    (emacspeak-auditory-icon 'select-object)
    (emacspeak-speak-line)))

;;}}}
;;{{{ speech enable  eudc widgets 

(defun emacspeak-eudc-widget-help (widget)
  "Provides emacspeak help for eudc widgets. "
  (cond
   ((eq (widget-type widget) 'editable-field)
    (concat (thing-at-point 'line) 
            "Edit "))
   ((eq (widget-type widget) 'push-button)
    (concat "Push button "
            (widget-value widget )))
   (t (emacspeak-widget-default-summarize widget ))))

(defun emacspeak-eudc-widgets-add-emacspeak-help ()
  "Adds emacspeak widget help to all EUDC widgets. "
  (save-excursion 
    (goto-char (point-min))
    (while  (not (eobp))
      (goto-char (next-overlay-change (point)))
      (when (widget-at (point))
        (widget-put (widget-at (point))
                    :emacspeak-help 
                    'emacspeak-eudc-widget-help)
        (forward-line 1)))))

(defadvice eudc-query-form (after emacspeak pre act comp )
  "Attach emacspeak help to all EUDC widgets.
Summarize the form to welcome the user. "
  (emacspeak-eudc-widgets-add-emacspeak-help)
  (emacspeak-auditory-icon 'open-object)
  (let((server "Server ")
       (host eudc-server))
    (put-text-property 0  (length host)
                       'personality voice-animate
                       host)
    (put-text-property 0  (length server)
                       'personality voice-annotate
                       server)
    (dtk-speak 
     (concat server 
             " " 
             host 
             " " 
             (when (widget-at (point))
               (emacspeak-eudc-widget-help (widget-at (point))))))))

;;}}}
;;{{{ additional interactive commands 

(defun emacspeak-eudc-send-mail ()
  "Send email to the address given by the current record. "
  (interactive)
  (unless (eq major-mode  'eudc-mode)
    (error "This command should be called in EUDC buffers. "))
  (let ((record
         (overlay-get (car (overlays-at (point))) 'eudc-record))
        (mail nil))
    (unless record (error "Not on a record. "))
    (setq mail
          (cdr (assq 'mail record)))
    (if mail
        (sendmail-user-agent-compose mail)
      (error "Cannot determine email address from record %s"
             (cdr (assq 'mail record))))))

;;}}}
;;{{{ bind additional commands 
(declaim (special eudc-mode-map))
(define-key eudc-mode-map "m" 'emacspeak-eudc-send-mail)

;;}}}
;;{{{ voiceify values in results 

(defgroup emacspeak-eudc nil
  "Emacspeak add-on to the Emacs Universal Directory Client."
  :group 'emacspeak
  :group 'eudc
  :prefix "emacspeak-eudc-")

(defcustom emacspeak-eudc-attribute-value-personality
  voice-animate
  "Personality t use for voiceifying attribute values. "
  :type 'symbol
  :group 'emacspeak-eudc)

(defadvice eudc-print-attribute-value (around emacspeak pre
                                              act comp)
  "voiceify attribute values"
  (cond
   ((not emacspeak-eudc-attribute-value-personality)
    ad-do-it)
   (t (let ((start (point)))
        ad-do-it
        (with-silent-modifications
          (put-text-property start (point)
                             'personality
                             emacspeak-eudc-attribute-value-personality)))))
  ad-return-value)

;;}}}
(provide 'emacspeak-eudc)
;;{{{ end of file

;;; local variables:
;;; folded-file: t
;;; byte-compile-dynamic: nil
;;; end:

;;}}}
