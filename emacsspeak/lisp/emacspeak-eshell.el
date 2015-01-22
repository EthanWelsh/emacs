;;; emacspeak-eshell.el --- Speech-enable EShell - Emacs Shell
;;; $Id: emacspeak-eshell.el 8146 2013-02-09 20:05:08Z tv.raman.tv $
;;; $Author: tv.raman.tv $
;;; Description:   Speech-enable EShell
;;; Keywords: Emacspeak, Audio Desktop
;;{{{  LCD Archive entry:

;;; LCD Archive Entry:
;;; emacspeak| T. V. Raman |raman@cs.cornell.edu
;;; A speech interface to Emacs |
;;; $Date: 2007-09-01 15:30:13 -0700 (Sat, 01 Sep 2007) $ |
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

;;{{{  Introduction:

;;; Commentary:
;;; EShell is a shell implemented entirely in Emacs Lisp.
;;; It is part of emacs 21 --and can also be used under
;;; Emacs 20.
;;; This module speech-enables EShell
;;; Code:

;;}}}
;;{{{ required modules

(require 'emacspeak-preamble)
(require 'esh-arg)

;;}}}
;;{{{  setup various EShell hooks

;;; Play an auditory icon as you display the prompt
(defun emacspeak-eshell-prompt-function ()
  "Play auditory icon for prompt."
  (declare (special eshell-last-command-status))
  (cond
   ((= 0 eshell-last-command-status)
    (emacspeak-auditory-icon 'item))
   (t (emacspeak-auditory-icon 'warn-user))))

(add-hook 'eshell-after-prompt-hook 'emacspeak-eshell-prompt-function)

;;; Speak command output

(defun emacspeak-eshell-speak-output  ()
  "Speak eshell output."
  (declare (special eshell-last-input-end eshell-last-output-end
                    eshell-last-output-start))
  (emacspeak-speak-region eshell-last-input-end eshell-last-output-end))

(add-hook 
 'eshell-output-filter-functions
 'emacspeak-eshell-speak-output
 'at-end)

;;}}}
;;{{{  Advice top-level EShell

(defadvice eshell (after emacspeak pre act )
  "Announce switching to shell mode.
Provide an auditory icon if possible."
  (when (ems-interactive-p )
    (emacspeak-auditory-icon 'select-object )
    (emacspeak-setup-programming-mode)
    (emacspeak-dtk-sync)
    (emacspeak-speak-line)))

;;}}}
;;{{{ advice em-hist

(loop for f in
      '(
        eshell-next-input eshell-previous-input
                          eshell-next-matching-input eshell-previous-matching-input
                          eshell-next-matching-input-from-input eshell-previous-matching-input-from-input)
      do
      (eval
       `(defadvice ,f (after  emacspeak pre act comp)
          "Speak selected command."
          (when (ems-interactive-p )
            (emacspeak-auditory-icon 'select-object)
            (save-excursion
              (beginning-of-line)
              (eshell-skip-prompt)
              (emacspeak-speak-line 1))))))

;;}}}
;;{{{  advice em-ls

(defgroup emacspeak-eshell nil
  "EShell on the Emacspeak Audio Desktop."
  :group 'emacspeak
  :group 'eshell
  :prefix "emacspeak-eshell-")

(defcustom emacspeak-eshell-ls-use-personalities t
  "Indicates if ls in eshell uses different voice
personalities."
  :type 'boolean
  :group 'emacspeak-eshell)

;;}}}
;;{{{ voices

(voice-setup-add-map
 '(
   (eshell-ls-archive voice-lighten-extra)
   (eshell-ls-archive-face voice-lighten-extra)
   (eshell-ls-backup voice-monotone-medium)
   (eshell-ls-backup-face voice-monotone-medium)
   (eshell-ls-clutter voice-smoothen-extra)
   (eshell-ls-clutter-face voice-smoothen-extra)
   (eshell-ls-directory voice-bolden)
   (eshell-ls-directory-face voice-bolden)
   (eshell-ls-executable voice-animate-extra)
   (eshell-ls-executable-face voice-animate-extra)
   (eshell-ls-missing voice-brighten)
   (eshell-ls-missing-face voice-brighten)
   (eshell-ls-product voice-lighten-medium)
   (eshell-ls-product-face voice-lighten-medium)
   (eshell-ls-readonly voice-monotone)
   (eshell-ls-readonly-face voice-monotone)
   (eshell-ls-special voice-lighten-extra)
   (eshell-ls-special-face voice-lighten-extra)
   (eshell-ls-symlink voice-smoothen)
   (eshell-ls-symlink-face voice-smoothen)
   (eshell-ls-unreadable voice-monotone-medium)
   (eshell-ls-unreadable-face voice-monotone-medium)
   (eshell-prompt voice-animate)
   (eshell-prompt-face voice-animate)
   ))

;;}}}
;;{{{ Advice em-prompt

(loop for f in
      '(
        eshell-next-prompt eshell-previous-prompt
                           eshell-forward-matching-input  eshell-backward-matching-input)
      do
      (eval
       `(defadvice ,f (after  emacspeak pre act comp)
          "Speak selected command."
          (when (ems-interactive-p )
            (let ((emacspeak-speak-messages nil))
              (emacspeak-auditory-icon 'select-object)
              (emacspeak-speak-line 1))))))

;;}}}
;;{{{  advice esh-arg

(loop for f in
      '(
        eshell-insert-buffer-name
        eshell-insert-process
        eshell-insert-envvar)
      do
      (eval
       `(defadvice ,f (after emacspeak pre act comp)
          "Speak output."
          (when (ems-interactive-p )
            (emacspeak-auditory-icon 'select-object)
            (emacspeak-speak-line)))))

(defadvice eshell-insert-process (after emacspeak pre
                                        act comp)
  "Speak output."
  (when (ems-interactive-p )
    (emacspeak-auditory-icon 'select-object)
    (emacspeak-speak-line)))

;;}}}
;;{{{ advice esh-mode

(defadvice eshell-delchar-or-maybe-eof (around emacspeak pre act)
  "Speak character you're deleting."
  (cond
   ((ems-interactive-p  )
    (cond
     ((= (point) (point-max))
      (message "Sending EOF to comint process"))
     (t (dtk-tone 500 30 'force)
        (emacspeak-speak-char t)))
    ad-do-it)
   (t ad-do-it))
  ad-return-value)

(defadvice eshell-delete-backward-char (around emacspeak pre act)
  "Speak character you're deleting."
  (cond
   ((ems-interactive-p  )
    (dtk-tone 500 30 'force)
    (emacspeak-speak-this-char (preceding-char ))
    ad-do-it)
   (t ad-do-it))
  ad-return-value)

(defadvice eshell-show-output (after emacspeak pre act comp)
  "Speak output."
  (when (ems-interactive-p )
    (let ((emacspeak-show-point t))
      (emacspeak-auditory-icon 'large-movement)
      (emacspeak-speak-region (point) (mark)))))
(defadvice eshell-mark-output (after emacspeak pre act comp)
  "Speak output."
  (when (ems-interactive-p )
    (let ((emacspeak-show-point t))
      (emacspeak-auditory-icon 'mark-object)
      (emacspeak-speak-line))))
(defadvice eshell-kill-output (after emacspeak pre act comp)
  "Produce auditory feedback."
  (when (ems-interactive-p )
    (emacspeak-auditory-icon 'delete-object)
    (message "Flushed output")))

(defadvice eshell-kill-input (before emacspeak pre act )
  "Provide spoken feedback."
  (when (ems-interactive-p )
    (emacspeak-auditory-icon 'delete-object )
    (emacspeak-speak-line)))

(defadvice eshell-toggle (after emacspeak pre act comp)
  "Provide spoken context feedback."
  (when (ems-interactive-p )
    (cond
     ((eq major-mode 'eshell-mode)
      (emacspeak-setup-programming-mode)
      (emacspeak-speak-line))
     (t (emacspeak-speak-mode-line)))
    (emacspeak-auditory-icon 'select-object)))
(defadvice eshell-toggle-cd (after emacspeak pre act comp)
  "Provide spoken context feedback."
  (when (ems-interactive-p )
    (cond
     ((eq major-mode 'eshell-mode)
      (emacspeak-speak-line))
     (t (emacspeak-speak-mode-line)))
    (emacspeak-auditory-icon 'select-object)))

;;}}}

(provide 'emacspeak-eshell)
;;{{{ end of file

;;; local variables:
;;; folded-file: t
;;; byte-compile-dynamic: nil
;;; end:

;;}}}
