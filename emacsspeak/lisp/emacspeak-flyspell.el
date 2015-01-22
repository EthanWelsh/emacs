;;; emacspeak-ispell.el --- Speech enable Ispell -- Emacs' interactive spell checker
;;; $Id: emacspeak-flyspell.el 8574 2013-11-24 02:01:07Z tv.raman.tv $
;;; $Author: tv.raman.tv $ 
;;; Description:  Emacspeak extension to speech enable flyspell
;;; Keywords: Emacspeak, Ispell, Spoken Output, fly spell checking
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

;;; This module speech enables flyspell.

;;}}}
;;{{{ Requires
(require 'cl)
(declaim  (optimize  (safety 0) (speed 3)))
(require 'emacspeak-preamble)
(require 'flyspell)
;;}}}
;;{{{  define personalities

(defgroup emacspeak-flyspell nil
  "Emacspeak support for on the fly spell checking."
  :group 'emacspeak
  :group 'flyspell
  :prefix "emacspeak-flyspell-")

(voice-setup-add-map
 '(
   (flyspell-incorrect voice-bolden)
   ))

;;}}}
;;{{{ advice

(declaim (special flyspell-delayed-commands))
(push 'emacspeak-self-insert-command flyspell-delayed-commands)
(defadvice flyspell-auto-correct-word (around emacspeak pre act comp)
  "Speak the correction we inserted"
  (cond
   ((ems-interactive-p )
    ad-do-it
    (dtk-speak (car  (flyspell-get-word nil)))
    (emacspeak-auditory-icon 'select-object))
   (t ad-do-it))
  ad-return-value)

(defadvice flyspell-unhighlight-at (before debug pre act comp)
  (let ((overlay-list (overlays-at pos))
        (o nil))
    (while overlay-list 
      (setq o (car overlay-list))
      (when (flyspell-overlay-p o)
        (put-text-property (overlay-start o)
                           (overlay-end o)
                           'personality  nil))
      (setq overlay-list (cdr overlay-list)))))

;;}}}
;;{{{  Highlighting the error 

(defun emacspeak-flyspell-highlight-incorrect-word (beg end ignore)
  "Put property personality with value
`voice-animate' from beg to end"
  (declare (special voice-animate))
  (with-silent-modifications
    (put-text-property beg end 'personality
                       voice-animate))
  (emacspeak-speak-region beg end)
  nil)

(add-hook 'flyspell-incorrect-hook 'emacspeak-flyspell-highlight-incorrect-word)

;;}}}
(provide 'emacspeak-flyspell)
;;{{{  emacs local variables 

;;; local variables:
;;; folded-file: t
;;; byte-compile-dynamic: nil
;;; end: 

;;}}}
