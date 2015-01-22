;;; emacspeak-python.el --- Speech enable Python development environment
;;; $Id: emacspeak-py.el 8327 2013-05-06 16:02:13Z tv.raman.tv $
;;; $Author: tv.raman.tv $ 
;;; Description: Auditory interface to python mode
;;; Keywords: Emacspeak, Speak, Spoken Output, python
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

;;; Copyright (c) 1995 -- 2011, T. V. Raman
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

;;{{{ Introduction

;;; Commentary:

;;; This speech-enables python-mode available on sourceforge

;;; Code:

;;}}}
;;{{{  Required modules

(require 'emacspeak-preamble)

;;}}}
;;{{{ Advice interactive commands:

;;{{{  electric editing
(unless (and (boundp 'post-self-insert-hook)
             post-self-insert-hook
             (memq 'emacspeak-post-self-insert-hook post-self-insert-hook))
  (defadvice py-electric-comment (after emacspeak pre act comp)
    "Speak what you inserted"
    (when (ems-interactive-p )
      (dtk-say " pound "))))

(unless (and (boundp 'post-self-insert-hook)
             post-self-insert-hook
             (memq 'emacspeak-post-self-insert-hook post-self-insert-hook))
  (defadvice py-electric-colon (after emacspeak pre act comp)
    "Speak what you inserted")
  (when (ems-interactive-p )
    (dtk-say " colon ")))

(defadvice py-electric-backspace (around emacspeak pre act)
  "Speak character you're deleting."
  (cond
   ((ems-interactive-p  )
    (dtk-tone 500 30 'force)
    (emacspeak-speak-this-char (preceding-char ))
    ad-do-it)
   (t ad-do-it))
  ad-return-value)

(defadvice py-electric-delete (around emacspeak pre act)
  "Speak character you're deleting."
  (cond
   ((ems-interactive-p  )
    (dtk-tone 500 30 'force)
    (emacspeak-speak-this-char (preceding-char ))
    ad-do-it)
   (t ad-do-it))
  ad-return-value)

;;}}}
;;{{{ interactive programming

(defadvice py-shell (after emacspeak pre act comp)
  "Provide auditory feedback"
  (when (ems-interactive-p )
    (emacspeak-auditory-icon 'select-object)
    (emacspeak-speak-mode-line)))

(defadvice py-clear-queue (after emacspeak pre act comp)
  "Provide auditory feedback"
  (when (ems-interactive-p )
    (emacspeak-auditory-icon 'task-done)))

(defadvice py-execute-region (after emacspeak pre act comp)
  "Provide auditory feedback"
  (when (ems-interactive-p )
    (emacspeak-auditory-icon 'task-done)))

(defadvice py-execute-buffer (after emacspeak pre act comp)
  "Provide auditory feedback"
  (when (ems-interactive-p )
    (emacspeak-auditory-icon 'task-done)))

(defadvice py-goto-exception(after emacspeak pre act comp)
  "Speak line you moved to"
  (when (ems-interactive-p )
    (emacspeak-auditory-icon 'large-movement)
    (emacspeak-speak-line)))

(defadvice py-down-exception(after emacspeak pre act comp)
  "Speak line you moved to"
  (when (ems-interactive-p )
    (emacspeak-auditory-icon 'large-movement)
    (emacspeak-speak-line)))

(defadvice py-up-exception(after emacspeak pre act comp)
  "Speak line you moved to"
  (when (ems-interactive-p )
    (emacspeak-auditory-icon 'large-movement)
    (emacspeak-speak-line)))

;;}}}
;;{{{  whitespace management and indentation
(loop for f in
      (list 'py-fill-paragraph
            'py-fill-comment
            'py-fill-string)
      do
      (eval
       `(defadvice ,f (after emacspeak pre act comp)
          "Provide auditory feedback."
          (when (ems-interactive-p )
            (emacspeak-auditory-icon 'fill-object)))))

(defadvice py-newline-and-indent(after emacspeak pre act comp)
  "Speak line so we know current indentation"
  (when (ems-interactive-p )
    (dtk-speak-using-voice voice-annotate
                           (format
                            "indent %s"
                            (current-column)))
    (dtk-force)))

(defadvice py-shift-region-left (after emacspeak pre act comp)
  "Speak number of lines that were shifted"
  (when (ems-interactive-p )
    (emacspeak-auditory-icon 'large-movement)
    (dtk-speak
     (format "Left shifted block  containing %s lines"
             (count-lines  (region-beginning)
                           (region-end))))))

(defadvice py-shift-region-right (after emacspeak pre act comp)
  "Speak number of lines that were shifted"
  (when (ems-interactive-p )
    (dtk-speak
     (format "Right shifted block  containing %s lines"
             (count-lines  (region-beginning)
                           (region-end))))))
(defadvice py-indent-region (after emacspeak pre act comp)
  "Speak number of lines that were shifted"
  (when (ems-interactive-p )
    (emacspeak-auditory-icon 'large-movement)
    (dtk-speak
     (format "Indented region   containing %s lines"
             (count-lines  (region-beginning)
                           (region-end))))))

(defadvice py-comment-region (after emacspeak pre act comp)
  "Speak number of lines that were shifted"
  (when (ems-interactive-p )
    (dtk-speak
     (format "Commented  block  containing %s lines"
             (count-lines  (region-beginning)
                           (region-end))))))

;;}}}
;;{{{  buffer navigation
(defadvice py-previous-statement (after emacspeak pre act comp)
  "Speak current statement after moving"
  (when (ems-interactive-p )
    (emacspeak-speak-line)
    (emacspeak-auditory-icon 'large-movement)))
(defadvice py-next-statement (after emacspeak pre act comp)
  "Speak current statement after moving"
  (when (ems-interactive-p )
    (emacspeak-speak-line)
    (emacspeak-auditory-icon 'large-movement)))

(defadvice py-goto-block-up (after emacspeak pre act comp)
  "Speak current statement after moving"
  (when (ems-interactive-p )
    (emacspeak-speak-line)
    (emacspeak-auditory-icon 'large-movement)))

(defadvice py-beginning-of-def-or-class (after emacspeak pre act comp)
  "Speak current statement after moving"
  (when (ems-interactive-p )
    (emacspeak-speak-line)
    (emacspeak-auditory-icon 'large-movement)))

(defadvice beginning-of-python-def-or-class (after emacspeak pre act comp)
  "Speak current statement after moving"
  (when (ems-interactive-p )
    (emacspeak-speak-line)
    (emacspeak-auditory-icon 'large-movement)))

(defadvice end-of-python-def-or-class (after emacspeak pre act comp)
  "Speak current statement after moving"
  (when (ems-interactive-p )
    (emacspeak-speak-line)
    (emacspeak-auditory-icon 'large-movement)))

(defadvice py-end-of-def-or-class (after emacspeak pre act comp)
  "Speak current statement after moving"
  (when (ems-interactive-p )
    (emacspeak-speak-line)
    (emacspeak-auditory-icon 'large-movement)))

(defadvice py-mark-block (after emacspeak pre act comp)
  "Speak number of lines marked"
  (when (ems-interactive-p )
    (dtk-speak
     (format "Marked block containing %s lines"
             (count-lines (region-beginning)
                          (region-end))))
    (emacspeak-auditory-icon 'mark-object)))
(defadvice py-narrow-to-defun (after emacspeak pre act comp)
  "Provide auditory feedback."
  (when (ems-interactive-p )
    (message "%s %s lines"
             (save-excursion
               (goto-char (point-min))
               (buffer-substring (line-beginning-position)
                                 (line-end-position)))
             (count-lines (point-min)
                          (point-max)))))

(defadvice py-mark-def-or-class (after emacspeak pre act comp)
  "Speak number of lines marked"
  (when (ems-interactive-p )
    (dtk-speak
     (format "Marked block containing %s lines"
             (count-lines (region-beginning)
                          (region-end))))
    (emacspeak-auditory-icon 'mark-object)))

(defadvice py-forward-into-nomenclature(after emacspeak pre act comp)
  "Speak rest of current word"
  (when (ems-interactive-p )
    (emacspeak-speak-word 1)))

(defadvice py-backward-into-nomenclature(after emacspeak pre act comp)
  "Speak rest of current word"
  (when (ems-interactive-p )
    (emacspeak-speak-word 1)))

;;}}}
;;{{{ the process buffer

(defadvice py-process-filter (around emacspeak pre act)
  "Make comint in Python speak its output. "
  (declare (special emacspeak-comint-autospeak))
  (let ((prior (point ))
        (dtk-stop-immediately nil))
    ad-do-it 
    (when (and  emacspeak-comint-autospeak
                (window-live-p
                 (get-buffer-window (process-buffer (ad-get-arg 0)))))
      (condition-case nil
          (emacspeak-speak-region prior (point ))
        (error (emacspeak-auditory-icon 'scroll)
               (dtk-stop ))))
    ad-return-value))

;;}}}

;;}}}
;;{{{ Additional navigation
(defun emacspeak-py-previous-block()
  "Move backward to the beginning of the current block.
If already at the beginning then move to previous block."
  (interactive)
  (let ((start (point)))
    (beginning-of-python-def-or-class)
    (unless (eq start (point))
      (beginning-of-line)
      (emacspeak-speak-line)
      (emacspeak-auditory-icon 'large-movement))))

(defun emacspeak-py-next-block()
  "Move forward to the beginning of the next block."
  (interactive)
  (end-of-python-def-or-class)
  (skip-syntax-forward " ")
  (forward-line 1)
  (beginning-of-line)
  (emacspeak-speak-line)
  (emacspeak-auditory-icon 'large-movement))

;;}}}
;;{{{ keybindings

(progn
  (declaim (special  python-mode-map))
  (define-key python-mode-map "\M-a" 'beginning-of-python-def-or-class)
  (define-key python-mode-map "\M-e" 'end-of-python-def-or-class)
  (define-key python-mode-map "\M-n" 'py-next-statement)
  (define-key python-mode-map "\M-p" 'py-previous-statement)
  (define-key python-mode-map "\C-\M-u" 'py-goto-block-up)
  (define-key python-mode-map "\C-\M-n" 'emacspeak-py-next-block)
  (define-key python-mode-map "\C-\M-p" 'emacspeak-py-previous-block)
  )
(add-hook 'python-mode-hook
          'emacspeak-setup-programming-mode)
;;}}}
;;{{{ Voice Mappings:
(voice-setup-add-map
 '(
   (py-number-face voice-lighten)
   (py-XXX-tag-face voice-animate)
   (py-pseudo-keyword-face voice-bolden-medium)
   (py-variable-name-face  emacspeak-voice-lock-variable-name-personality)
   (py-decorators-face voice-lighten)
   (py-builtins-face emacspeak-voice-lock-builtin-personality)
   (py-class-name-face voice-bolden-extra)
   (py-exception-name-face emacspeak-voice-lock-warning-personality)))

;;}}}
(provide 'emacspeak-py )
;;{{{ end of file 

;;; local variables:
;;; folded-file: t
;;; byte-compile-dynamic: nil
;;; end: 

;;}}}
