;;; amixer.el --- Control AMixer from Emacs
;;;$Id: amixer.el 8529 2013-11-11 20:23:38Z tv.raman.tv $
;;;Emacs front-end to AMixer
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
;;{{{ introduction

;;; Commentary:
;;; Provide an emacs front-end to amixer.
;;;amixer is part of ALSA

;;; Code:

;;}}}
;;{{{ required packages

(require 'cl)
(declaim  (optimize  (safety 0) (speed 3)))

;;}}}
;;{{{ Customizations:

;;}}}
;;{{{ Definitions

(defvar amixer-db nil
  "Holds cached values.")

(defstruct amixer-control
  numid iface name setting)

(declare-function amixer-control-name  "amixer.el" (amixer))
(declare-function amixer-control-numid  "amixer.el" (amixer))
(declare-function amixer-control-iface  "amixer.el" (amixer))
(defstruct amixer-control-setting
  type access values
  min max step
  current)

;;}}}
;;{{{ Manage amixer db:

(defun amixer-populate-settings (control)
  "Populate control with its settings information."
  (let ((scratch (get-buffer-create " *amixer*"))
        (fields nil)
        (slots nil)
        (current nil))
    (save-current-buffer
      (set-buffer scratch)
      (setq buffer-undo-list t)
      (erase-buffer)
      (shell-command
       (format "amixer cget numid=%s"
               (amixer-control-numid (cdr control)))
       (current-buffer))
      (goto-char (point-min))
      (forward-line 1)
      (setq fields
            (split-string
             (buffer-substring-no-properties
              (1+ (line-beginning-position))
              (line-end-position))
             ","))
      (setq slots
            (loop for f in fields
                  collect
                  (second (split-string f "="))))
      (while (and (not (eobp))
                  (looking-at "^ *;"))
        (forward-line 1))
      (setq current
            (second
             (split-string
              (buffer-substring-no-properties
               (line-beginning-position)
               (line-end-position))
              "=")))
      (setf (amixer-control-setting (cdr control))
            (make-amixer-control-setting
             :type (nth 0 slots)
             :access (nth 1 slots)
             :values (nth 2 slots)
             :min (nth 3 slots)
             :max (nth 4 slots)
             :step (nth 5 slots)
             :current current))))
  control)

(defun amixer-build-db ()
  "Create a database of amixer controls and their settings."
  (declare (special amixer-db))
  (unless (executable-find "amixer")
    (error "You dont have a standard amixer."))
  (let ((scratch (get-buffer-create " *amixer*"))
        (controls nil)
        (fields nil)
        (slots nil))
    (save-current-buffer
      (set-buffer scratch)
      (setq buffer-undo-list t)
      (erase-buffer)
      (shell-command "amixer controls | sed -e s/\\'//g"
                     (current-buffer))
      (goto-char (point-min))
      (while (not (eobp))
        (setq fields
              (split-string
               (buffer-substring-no-properties
                (line-beginning-position)
                (line-end-position))
               ","))
;;; only need 3 fields:
        (setq fields
              (list 
               (nth 0 fields)
               (nth 1 fields)
               (mapconcat #'identity (nthcdr 2 fields) " ")))
        (setq slots
              (loop for f in fields
                    collect
                    (second (split-string f "="))))
        (push
         (cons
          (third slots)
          (make-amixer-control
           :numid (first slots)
           :iface (second slots)
           :name (third slots)))
         controls)
        (forward-line 1))               ; done collecting controls
      (mapc #'amixer-populate-settings controls)
      (setq amixer-db controls))))

;;}}}
;;{{{ Amixer:

(defun amixer-get-enumerated-values(control)
  "Return list of enumerated values."
  (let ((buffer (get-buffer-create " *amixer*"))
        (values nil))
    (save-current-buffer
      (set-buffer buffer)
      (setq buffer-undo-list t)
      (erase-buffer)
      (shell-command
       (format
        "amixer cget numid=%s | grep Item | sed -e s/\\'//g"
        (amixer-control-numid control))
       (current-buffer))
      (goto-char (point-min))
      (while (not   (eobp))
        (beginning-of-line)
        (when (looking-at "^ *;")
          (search-forward "Item #" nil t)
          (push
           (buffer-substring-no-properties
            (point)
            (line-end-position))
           values))
        (forward-line 1))
      (nreverse values))))

;;;###autoload
(defun amixer (&optional refresh)
  "Interactively manipulate ALSA settings.
Interactive prefix arg refreshes cache."
  (interactive "P")
  (declare (special amixer-db))
  (when (or refresh
            (null amixer-db))
    (amixer-build-db))
  (let ((control
         (cdr
          (assoc
           (let ((completion-ignore-case t))
             (completing-read
              "Control:" amixer-db
              nil 'must-match))
           amixer-db)))
        (update nil)
        (choices nil))
    (cond
     ((null control)
      (shell-command "alsactl restore")
      (message "Resetting  sound to default")
      (amixer-build-db))
     (t
      (when (string=
             "ENUMERATED"
             (amixer-control-setting-type (amixer-control-setting control)))
        (setq choices
              (amixer-get-enumerated-values control)))
      (setq update
            (read-from-minibuffer 
             (format
              "Change %s from %s %s:"
              (amixer-control-name control)
              (amixer-control-setting-current
               (amixer-control-setting control))
              (or choices ""))))
      (setf
       (amixer-control-setting-current
        (amixer-control-setting control))
       update)
      (shell-command
       (format "amixer cset numid=%s %s"
               (amixer-control-numid control)
               update))
      (message
       "updated %s to %s"
       (amixer-control-name control)
       update)))))

;;}}}
(provide 'amixer)      
;;{{{ end of file

;;; local variables:
;;; folded-file: t
;;; byte-compile-dynamic: nil
;;; end:

;;}}}      
