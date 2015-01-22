;;; dtk-speak.el --- Provides Emacs Lisp interface to speech server
;;;$Id: dtk-speak.el 8500 2013-11-02 01:54:49Z tv.raman.tv $
;;; $Author: tv.raman.tv $
;;; Description:  Emacs interface to TTS
;;; Keywords: Dectalk Emacs Elisp
;;{{{  LCD Archive entry:

;;; LCD Archive Entry:
;;; emacspeak| T. V. Raman |raman@cs.cornell.edu
;;; A speech interface to Emacs |
;;; $Date: 2008-07-06 10:18:30 -0700 (Sun, 06 Jul 2008) $ |
;;;  $Revision: 4670 $ |
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

;;{{{ introduction:

;;; Commentary:
;;;Defines the TTS interface.

;;; Code:
;;

;;}}}
;;{{{ required modules

;;;Code:

(require 'cl)
(declaim  (optimize  (safety 0) (speed 3)))
(require 'custom)
(require 'dtk-interp)
(require 'dtk-unicode)

(require 'espeak-voices)
(require 'flite-voices)

;;}}}
;;{{{ Forward Declarations:
(declare-function emacspeak-auditory-icon "emacspeak-sounds.el" (icon))
(declare-function emacspeak-queue-auditory-icon "emacspeak-sounds.el" (icon))
;;;###autoload 
(defvar dtk-program
  (or  (getenv "DTK_PROGRAM" ) "dtk-exp")
  "The program to use to talk to the speech engine.
Possible choices at present:
dtk-exp     For the Dectalk Express.
dtk-mv      for the Multivoice and older Dectalks.
outloud     For IBM ViaVoice Outloud
multispeech For Multilingual speech server
espeak      For eSpeak
The default is dtk-exp.")

(defvar dtk-program-args
  (when (getenv "DTK_PROGRAM_ARGS")
    (split-string   (getenv "DTK_PROGRAM_ARGS")))
  "Arguments passed to the dtk-program")

(defvar emacspeak-pronounce-pronunciation-table)
(defvar emacspeak-ssh-tts-server )
(defvar emacspeak-auditory-icon-function )
(defvar emacspeak-directory )
(defvar emacspeak-use-auditory-icons )
(defvar emacspeak-pronounce-pronunciation-personality )

;;}}}
;;{{{  user customizations:

(defgroup tts nil
  "Text To Speech (TTS) customizations for the Emacspeak audio desktop."
  :group 'emacspeak
  :prefix "dtk-")
;;;###autoload
(defcustom tts-strip-octals nil
  "Set to T to strip all octal chars before speaking.
Particularly useful for web browsing."
  :type 'boolean
  :group  'dtk
  :group  'tts)
(make-variable-buffer-local 'tts-strip-octals)

;;;###autoload
;;;###autoload
(defcustom dtk-speech-rate-base
  (if (string-match "dtk" dtk-program) 180 50)
  "*Value of lowest tolerable speech rate."
  :type 'integer
  :group 'tts)
;;;###autoload
(defcustom dtk-speech-rate-step
  (if (string-match "dtk" dtk-program) 50 8)
  "*Value of speech rate increment.
This determines step size used when setting speech rate via command
`dtk-set-predefined-speech-rate'.  Formula used is
dtk-speech-rate-base  +  dtk-speech-rate-step*level."
  :type 'integer
  :group 'tts)
;;;###autoload
(defcustom dtk-startup-hook nil
  "List of hooks to be run after starting up the speech server.
Set things like speech rate, punctuation mode etc in this
hook."
  :type 'hook
  :group 'tts)

(defvar dtk-quiet nil
  "Switch indicating if the speech synthesizer is to keep quiet.
Do not set this variable by hand.
See command `dtk-toggle-quiet' bound to \\[dtk-toggle-quiet].")
(make-variable-buffer-local 'dtk-quiet)

(defvar dtk-split-caps t
  "Flag indicating whether to use split caps when speaking.
Do not set this variable by hand, use command  `dtk-toggle-split-caps'
 bound to \\[dtk-toggle-split-caps].")
(make-variable-buffer-local 'dtk-split-caps)
;;;###autoload
(defcustom dtk-cleanup-patterns
  (list
   "." "_" "-"  "=" "/"  "+" "*" ":" ";" "%"
   "{" "}" "~" "$" ")" "#" "/\\" "<>" )
  "List of repeating patterns to clean up.
You can use  command  `dtk-add-cleanup-pattern'
 bound to \\[dtk-add-cleanup-pattern]  to add more patterns.
Specify patterns that people use to decorate their ASCII files, and cause
untold pain to the speech synthesizer.

If more than 3 consecutive occurrences
of a specified pattern is found, the TTS engine replaces it
with a repeat count. "
  :type '(repeat  (string :tag "pattern"))
  :group 'tts)

;;}}}
;;{{{  internal variables

(defvar dtk-character-scale 1.25
  "Factor by which speech rate is scaled when characters are spoken.
Do not set this variable by hand, use command
`dtk-set-character-scale' bound to \\[dtk-set-character-scale].")

(defvar dtk-capitalize nil
  "Non-nil means produce a beep to indicate  capitalization.
Do not set this variable by hand, use command dtk-toggle-capitalization
bound to \\[dtk-toggle-capitalization].")
(make-variable-buffer-local 'dtk-capitalize)

(defvar dtk-allcaps-beep nil
  "Option to indicate capitalization.
Non-nil means produce a beep to indicate upper case words in conjunction with
split caps Do not set this variable by hand, use command
`dtk-toggle-allcaps-beep' bound to \\[dtk-toggle-allcaps-beep].")

(defconst dtk-punctuation-mode-alist
  '("some" "all" "none")
  "Alist of valid punctuation modes.")

(defvar dtk-last-output nil
  "Variable holding last output.")

(defvar dtk-speech-rate
  (if (string-match "dtk" dtk-program)
      225 100)
  "Rate at which tts talks.
Do not modify this variable directly; use command  `dtk-set-rate'
 bound to \\[dtk-set-rate].")

(make-variable-buffer-local 'dtk-speech-rate)

;;;declared here to help compilation
(defvar voice-lock-mode nil)

;;}}}
;;{{{ helper: apply pronunciations
;;; moved here from the emacspeak-pronounce module for efficient
;;compilation

(defsubst tts-apply-pronunciations (pronunciation-table )
  "Applies pronunciations specified in pronunciation table to current buffer.
Modifies text and point in buffer."
  (declare (special emacspeak-pronounce-pronunciation-personality))
  (let ((words
         (sort
          (loop for  key  being the hash-keys  of pronunciation-table collect key)
          #'(lambda (a b )
              (> (length  a) (length  b))))))
    (loop for key in words
          do
          (let ((word  key)
                (pronunciation (gethash  key pronunciation-table))
                (pp nil)
                (personality nil))
            (when word
              (goto-char (point-min))
              (cond
               ((stringp pronunciation)
                (while (search-forward  word nil t)
                  (setq pp (get-text-property (point) 'personality))
                  (replace-match  pronunciation t t  )
                  (when (or pp emacspeak-pronounce-pronunciation-personality)
                    (put-text-property
                     (match-beginning 0)
                     (+ (match-beginning 0) (length pronunciation))
                     'personality
                     (cond
                      ((and emacspeak-pronounce-pronunciation-personality
                            (listp pp))
                       (nconc pp (list emacspeak-pronounce-pronunciation-personality)))
                      (t pp))))))
               ((consp pronunciation )
                (let ((matcher (car pronunciation))
                      (pronouncer (cdr pronunciation))
                      (pronunciation ""))
                  (while (funcall matcher   word nil t)
                    (setq pp (get-text-property (point) 'personality))
                    (setq pronunciation
                          (save-match-data
                            (funcall pronouncer
                                     (buffer-substring
                                      (match-beginning 0)
                                      (match-end 0)))))
                    (replace-match pronunciation t t  )
                    (when (or pp emacspeak-pronounce-pronunciation-personality)
                      (put-text-property
                       (match-beginning 0)
                       (+ (match-beginning 0) (length pronunciation))
                       'personality
                       (cond
                        ((and emacspeak-pronounce-pronunciation-personality
                              (listp pp))
                         (nconc pp (list emacspeak-pronounce-pronunciation-personality)))
                        (t pp)))))))
               (t nil)))))))

;;}}}
;;{{{  Helpers to handle invisible text:

(defsubst text-visible-p (position)
  (not (invisible-p position)))
(unless (fboundp 'invisible-p)
;;; defined in simple.el in Emacs 23.
  (defsubst invisible-p (pos)
    "Check if text is invisible. Emacspeak helper."
    (declare (special buffer-invisibility-spec))
    (let ((prop (get-char-property pos 'invisible)))
      (if (eq buffer-invisibility-spec t)
          prop
        (or (memq prop buffer-invisibility-spec)
            (assq prop buffer-invisibility-spec)))))
  ) ;;; needed before Emacs 23.

(defsubst skip-invisible-forward  ()
  (while (and(not (eobp))
             (invisible-p (point)))
    (goto-char
     (next-single-char-property-change (point) 'invisible
                                       (current-buffer) (point-max)))))

(defsubst skip-invisible-backward  ()
  "Move backwards over invisible text."
  (while (and(not (bobp))
             (invisible-p (point)))
    (goto-char
     (previous-single-char-property-change (point) 'invisible
                                           (current-buffer) (point-min)))))

(defsubst delete-invisible-text ()
  "Delete invisible text."
  (goto-char (point-min))
  (let ((start  (point )))
    (while (not (eobp))
      (cond
       ((invisible-p (point ))
        (skip-invisible-forward)
        (delete-region  start (point ))
        (setq start (point )))
       (t (goto-char
           (or (next-single-property-change (point) 'invisible )
               (point-max )))
          (setq start (point)))))))

;;}}}
;;{{{  define inline functions first

(defsubst dtk-silence (duration &optional force)
  "Produce silence.
Argument DURATION  specifies number of milliseconds to pause.
Optional argument FORCE  flushes the command to the speech server."
  (declare (special dtk-quiet dtk-speaker-process
                    dtk-speak-server-initialized))
  (unless dtk-quiet
    (when dtk-speak-server-initialized
      (dtk-interp-silence duration
                          (if force "\nd" "")))))

;;;###autoload
(defcustom dtk-use-tones t
  "Allow tones to be turned off."
  :type 'boolean
  :group 'tts)

(defsubst dtk-tone (pitch duration &optional force)
  "Produce a tone.
Argument PITCH   is specified in hertz.
Argument DURATION  is specified in milliseconds.
Optional argument FORCE  flushes the command to the speech server."
  (declare (special dtk-quiet dtk-speaker-process
                    dtk-use-tones dtk-speak-server-initialized))
  (unless
      (or dtk-quiet
          (not dtk-use-tones)
          (not dtk-speak-server-initialized))
    (dtk-interp-tone pitch duration force)))

(defun dtk-set-language (lang)
  "Set language according to the argument lang."
  (interactive "sEnter new language: \n")
  (declare (special dtk-quiet dtk-speaker-process
                    dtk-speak-server-initialized))
  (when dtk-speak-server-initialized (dtk-interp-language lang (ems-interactive-p ))))

(defun dtk-set-next-language ()
  "Switch to the next available language"
  (interactive)
  (declare (special dtk-speak-server-initialized))
  (when dtk-speak-server-initialized
    (dtk-interp-next-language (ems-interactive-p ))))
;;)

(defun dtk-set-previous-language ()
  "Switch to the previous available language"
  (interactive)
  (declare (special dtk-quiet dtk-speaker-process
                    dtk-speak-server-initialized))
  ;;  (unless dtk-quiet
  (when dtk-speak-server-initialized
    (dtk-interp-previous-language (ems-interactive-p ))))
;;)

(defun dtk-set-preferred-language (alias lang)
  "Set the alias of the preferred language:
For example if alias=\"en\" lang=\"en_GB\",
then the following call:
 dtk-set-language(\"en\")
will set \"en_GB\".
"
  (interactive "s")
  (declare (special dtk-quiet dtk-speaker-process
                    dtk-speak-server-initialized))
  ;;  (unless dtk-quiet
  (when dtk-speak-server-initialized
    (dtk-interp-preferred-language alias lang)))
;;)

(defun dtk-list-language ()
  "Say the available languages."
  (declare (special dtk-quiet dtk-speaker-process
                    dtk-speak-server-initialized))
  (unless dtk-quiet
    (when dtk-speak-server-initialized
      (dtk-interp-list-language)))
  )

;;; helper function:

;;; Quote the string in current buffer so tcl does not barf.
;;; Fix brackets by changing to text.
;;; This is necessary because
;;;  [] marks dtk commands; {} is special to tcl
;;; Optionally post-process the text with cleanup function if one is specified.
(defconst dtk-bracket-regexp
  "[][{}<>\\|`#\n]"
  "Brackets and other chars  that are special to dtk and tcl.
Newlines  become spaces so each server request is a single line.
{} is special to tcl.
[] is special to both dtk and tcl.
<> and | are fixed to improve pronunciation.
\\ is fixed because it tends to be a metacharacter")

(defsubst dtk-strip-octals ()
  "Remove all octal chars."
  (let ((inhibit-read-only t))
    (goto-char (point-min))
    (while (re-search-forward "[\177-\377]+"  nil t )
      (replace-match " "))))

(defsubst  dtk-fix-brackets (mode)
  "Quote any delimiters that need special treatment.
Argument MODE  specifies the current pronunciation mode --- See \\[dtk-bracket-regexp]"
  (declare  (special dtk-bracket-regexp ))
  (let ((inhibit-read-only t))
    (goto-char (point-min))
    (cond
     ((eq 'all mode)
      (let ((start nil)
            (personality nil))
        (while (re-search-forward dtk-bracket-regexp  nil t )
          (setq start (1- (point)))
          (setq personality
                (get-text-property
                 start 'personality))
          (cond
           ((= 10  (char-after (match-beginning 0 ))) ; newline
            (replace-match " "))
           ((= ?| (char-after (match-beginning 0 )))
            (replace-match " pipe "))
           ((= ?< (char-after (match-beginning 0 )))
            (replace-match " less than "))
           ((= ?> (char-after (match-beginning 0 )))
            (replace-match " greater than "))
           ((= ?{ (char-after (match-beginning 0 )))
            (replace-match " left brace "))
           ((= ?} (char-after (match-beginning 0 )))
            (replace-match " right brace "))
           ((=  ?\] (char-after (match-beginning 0)))
            (replace-match " right bracket "))
           ((= ?\[ (char-after  (match-beginning 0)))
            (replace-match " left bracket "))
           ((= ?\\ (char-after (match-beginning 0 )))
            (replace-match " backslash "))
           ((= ?# (char-after (match-beginning 0 )))
            (replace-match " pound "))
           ((= ?` (char-after (match-beginning 0 )))
            (replace-match " backquote ")))
          (when personality
            (put-text-property start (point)
                               'personality personality)))))
     (t
      (while (re-search-forward dtk-bracket-regexp   nil t )
        (replace-match " " nil t ))))))

;;;###autoload
(defcustom dtk-speak-nonprinting-chars nil
  "*Option that specifies handling of non-printing chars.
Non nil value means non printing characters  should be
spoken as their octal value.
Set this to t to avoid a dectalk bug that makes the speech box die if
it seems some accented characters in certain contexts."
  :type 'boolean
  :group 'dtk)

(make-variable-buffer-local 'dtk-speak-nonprinting-chars)

(defvar dtk-octal-chars
  (if
      (and (boundp 'default-enable-multibyte-characters)
           default-enable-multibyte-characters)
      "[\000-\010\013\014\016-\037\177-\377]"
    "[\000-\010\013\014\016-\037]")
  "Regular expression matching control chars.
Set this once per emacspeak session for efficiency.")

(defsubst dtk-fix-control-chars ()
  "Handle control characters in speech stream."
  (declare (special dtk-character-to-speech-table
                    dtk-octal-chars
                    dtk-speak-nonprinting-chars))
  (let ((char nil))
    (goto-char (point-min ))
    (cond
     (tts-strip-octals ;;;Strip octals if asked to
      (dtk-strip-octals))
     (dtk-speak-nonprinting-chars
      (while (re-search-forward dtk-octal-chars nil t )
        (setq char (char-after (match-beginning 0)))
        (replace-match
         (format " %s " (aref  dtk-character-to-speech-table
                               char))))))))

;;; Takes a string, and replaces occurences of this pattern
;;; that are longer than 3 by a string of the form \"count
;;; string\". Second argument, mode, is the pronunciation
;;; mode being used to speak.  Removing repeated chars, and
;;; replacing them by a count:

(defsubst dtk-replace-duplicates (string mode)
  "Replace repeating patterns.
Argument STRING  specifies the repeating string to replace.
Argument MODE  specifies the current pronunciation mode."
  (let* ((inhibit-read-only t)
         (len (length string))
         (pattern (regexp-quote string))
         (reg (concat
               pattern pattern
               "\\(" pattern  "\\)+"))
         (start nil)
         (personality nil)
         (replacement nil))
    (while (re-search-forward reg nil t)
      (setq personality
            (get-text-property (point) 'personality))
      (setq replacement
            (if  (eq 'all  mode)
                (format " aw %s %s"
                        (/ (- (match-end 0 ) (match-beginning 0))
                           len)
                        (if (string-equal " " pattern)
                            " space " string))
              ""))
      (replace-match replacement)
      (setq start (- (point) (length replacement)))
      (when personality
        (put-text-property start (point)
                           'personality personality)))
    (goto-char (point-min))))
(defsubst dtk-handle-repeating-patterns (mode)
  (declare (special dtk-cleanup-patterns))
  (goto-char (point-min))
  (mapc
   #'(lambda (str)
       (dtk-replace-duplicates str mode ))
   dtk-cleanup-patterns ))

(defsubst  dtk-quote(mode )
;;; dtk will think it's processing a command otherwise:
  (dtk-fix-brackets mode)
;;; fix control chars
  (dtk-fix-control-chars))

(defsubst dtk-fix-backslash ()
  "Quote backslash characters as appropriate."
  (goto-char (point-min))
  (while (search-forward "\\" nil t)
    (replace-match " backslash ")))

;;; efficient quoting function for use in dtk-say
(defsubst  dtk-quick-quote(string )
  (let ((dtk-scratch-buffer (get-buffer-create " *dtk-scratch-buffer* "))
        (inhibit-read-only t))
    (save-current-buffer
      (set-buffer dtk-scratch-buffer)
      (setq buffer-undo-list t)
      (erase-buffer)
      (insert string)
      (goto-char (point-min))
;;; dtk will think it's processing a command otherwise:
      (dtk-fix-brackets 'all)
      (dtk-fix-backslash)
;;; fix control chars
      (dtk-fix-control-chars))))

;;; Moving  across a chunk of text.
;;; A chunk  is specified by a punctuation followed by whitespace
;;; or  multiple blank lines
;;; or a comment start or end
;;; or a parenthesis grouping start or end
;;; leaves point at the end of the chunk.
;;; returns  distance moved; nil if stationery
(defvar dtk-chunk-separator-syntax ".>)$\""
  "Syntax string to identify chunks when splitting text.")
                                        ; make it buffer local:
(make-variable-buffer-local 'dtk-chunk-separator-syntax)
(defsubst dtk-complement-chunk-separator-syntax ()
  "Return complement of syntactic class that splits clauses."
  (declare (special dtk-chunk-separator-syntax ))
  (concat "^" dtk-chunk-separator-syntax ))

;;; set chunk separator to match both whitespace and punctuations:
(defsubst dtk-chunk-on-white-space-and-punctuations()
  (declare (special dtk-chunk-separator-syntax))
  (setq dtk-chunk-separator-syntax
        (concat  dtk-chunk-separator-syntax " " )))

(defsubst dtk-chunk-only-on-punctuations()
  (declare (special dtk-chunk-separator-syntax))
  (setq dtk-chunk-separator-syntax
        (delete-if
         #'(lambda (x) (= x 32 ))
         dtk-chunk-separator-syntax)))

;;; invariance: looking at complement
;;; move across the complement and the following separator
;;; return value is a boolean indicating if we moved.
;;; side-effect is to move across a chunk
(defsubst  dtk-move-across-a-chunk (separator complement )
  "Move over a chunk of text.
Chunks are defined  based on major modes.
Argument SEPARATOR  is the syntax class of chunk separators.
Argument COMPLEMENT  is the complement of separator."
  (> (+ (skip-syntax-forward complement)
        (skip-syntax-forward separator))
     0))

;;; efficient way of voice changing

(defsubst dtk-speak-using-voice (voice text)
  "Use voice VOICE to speak text TEXT."
  (declare (special tts-voice-reset-code dtk-quiet))
                                        ; ensure text is a  string
  (unless (stringp text) (setq text (format "%s" text)))
  (unless (or (eq 'inaudible voice )
              dtk-quiet
              (null text)
              (string-equal  text "")
              (and (listp voice) (memq 'inaudible voice)))
    (dtk-interp-queue-code
     (cond
      ((symbolp voice)
       (tts-get-voice-command
        (if (boundp  voice )
            (symbol-value voice )
          voice)))
      ((listp voice)
       (mapconcat  #'(lambda (v)
                       (tts-get-voice-command
                        (if (boundp  v )
                            (symbol-value v )
                          v)))
                   voice
                   " "))
      (t       "")))
    (dtk-interp-queue text)
    (dtk-interp-queue-code tts-voice-reset-code)))

;;;Internal function used by dtk-speak to send text out.
;;;Handles voice locking etc.
;;; assumes in dtk-scratch-buffer
;;;start and end give the extent of the
;;;text to be spoken.
;;; note that property auditory-icon at the start  of a clause
;;; causes the sound
;;; to be queued.

(defsubst tts-get-overlay-auditory-icon (position)
  "Return auditory icon  at the front of the overlay list at position."
  (car
   (delete nil
           (mapcar
            #'(lambda (o)
                (overlay-get o 'auditory-icon))
            (overlays-at position)))))

(defsubst tts-get-overlay-personality (position)
  "Return personality at the front of the overlay list at position."
  (car
   (delete nil
           (mapcar
            #'(lambda (o)
                (overlay-get o 'personality))
            (overlays-at position)))))

(defsubst next-true-single-property-change (start  prop object  limit)
  "Similar to next-single-property-change, but compares property values with equal if they are not atoms."
  (let ((initial-value (get-text-property start  prop object)))
    (if (atom initial-value)
        (next-single-property-change start prop object limit)
      (let ((pos start))
        (while  (and (< pos limit)
                     (equal initial-value (get-text-property pos prop object)))
          (setq pos (next-single-property-change pos prop object limit)))
        pos))))

(defsubst dtk-format-text-and-speak (start end )
  "Format and speak text.
Arguments START and END specify region to speak."
  (declare (special voice-lock-mode dtk-speaker-process
                    tts-voice-reset-code
                    emacspeak-use-auditory-icons))
  (when (and emacspeak-use-auditory-icons
             (get-text-property start 'auditory-icon))
    (emacspeak-queue-auditory-icon
     (get-text-property start 'auditory-icon)))
  (dtk-interp-queue-code tts-voice-reset-code)
  (cond
   (voice-lock-mode
    (let ((last  nil)
          (personality (get-text-property start 'personality )))
      (while (and (< start end )
                  (setq last
                        (next-true-single-property-change start 'personality
                                                          (current-buffer) end)))
        (if personality
            (dtk-speak-using-voice personality (buffer-substring start last ))
          (dtk-interp-queue (buffer-substring  start last)))
        (setq start  last
              personality
              (get-text-property last  'personality))) ; end while
      ))                                ; end clause
   (t (dtk-interp-queue (buffer-substring start end  )))))

                                        ;Force the speech.
(defsubst dtk-force ()
  "Cause server to process all queued requests."
  (declare (special dtk-speaker-process))
  (dtk-interp-speak))

                                        ;Write out the string to the tts via TCLSH.
                                        ;No quoting is done, if want to quote the text, see dtk-speak
(defsubst dtk-dispatch (string)
  "Send request STRING to speech server."
  (declare (special dtk-speaker-process
                    dtk-speak-server-initialized
                    dtk-quiet))
  (unless dtk-quiet
    (when dtk-speak-server-initialized
      (dtk-interp-dispatch string ))))

;;;###autoload
(defsubst dtk-stop ()
  "Stop speech now."
  (interactive)
  (declare (special dtk-speaker-process))
  (dtk-interp-stop))

(defsubst dtk-reset-default-voice()
  (declare (special tts-default-voice))
  (dtk-dispatch (tts-get-voice-command tts-default-voice )))

;;}}}
;;{{{  adding cleanup patterns:

;;;###autoload
(defun dtk-add-cleanup-pattern (&optional delete )
  "Add this pattern to the list of repeating patterns that
are cleaned up.  Optional interactive prefix arg deletes
this pattern if previously added.  Cleaning up repeated
patterns results in emacspeak speaking the pattern followed
by a repeat count instead of speaking all the characters
making up the pattern.  Thus, by adding the repeating
pattern `.' (this is already added by default) emacspeak
will say ``aw fifteen dot'' when speaking the string
``...............'' instead of ``period period period period
''"
  (interactive "P")
  (declare (special dtk-cleanup-patterns ))
  (cond
   (delete
    (setq dtk-cleanup-patterns
          (delete
           (read-from-minibuffer "Specify repeating pattern to delete: ")
           dtk-cleanup-patterns)))
   (t (setq dtk-cleanup-patterns
            (cons
             (read-from-minibuffer "Specify repeating pattern: ")
             dtk-cleanup-patterns )))))

;;}}}
;;{{{  producing output

;;; Filter function to record last output from tcl

(defsubst dtk-filter-function (proc output)
  "Filter function for speech server.
Argument PROC is the server process.
Argument OUTPUT is the newly arrived output."
  (declare (special dtk-last-output))
  (setq dtk-last-output output))
;;; Uses the syntax table belonging to the buffer that owns the text
;;; to parse and speak the text intelligently.

(defvar dtk-speak-treat-embedded-punctuations-specially t
  "*If T then speech not split at embedded punctuations.")

(defvar dtk-speak-skim-scale 1.2
  "*Scale factor applied to speech rate when skimming.")

;;}}}
;;{{{ helper --generate state switcher:
;;;###autoload
(defun ems-generate-switcher (command switch documentation )
  "Generate desired command to switch the specified state."
  (eval
   `(defun ,command  (&optional prefix)
      ,documentation
      (interactive "P")
      (declare (special dtk-speaker-process ,switch ))
      (cond
       (prefix
        (setq-default  ,switch
                       (not  (default-value  ',switch)))
        (setq ,switch (default-value ',switch )))
       (t  (make-local-variable ',switch)
           (setq ,switch (not ,switch ))))
      (when
          (if (fboundp 'called-interactively-p)
              (called-interactively-p 'interactive)
            (interactive-p))
        (emacspeak-auditory-icon (if ,switch 'on 'off))
        (message "Turned %s %s  %s."
                 (if ,switch "on" "off" )
                 ',switch
                 (if prefix "" " locally"))))))

;;}}}
;;{{{  sending commands

;;;###autoload
(defun dtk-set-rate (rate    &optional prefix)
  "Set speaking RATE for the tts.
Interactive PREFIX arg means set   the global default value, and then set the
current local  value to the result."
  (interactive
   (list
    (read-from-minibuffer "Enter new rate: ")
    current-prefix-arg))
  (declare (special dtk-speech-rate dtk-speaker-process
                    tts-default-speech-rate
                    dtk-program dtk-speak-server-initialized))
  (when dtk-speak-server-initialized
    (cond
     (prefix
      (setq tts-default-speech-rate rate)
      (setq-default dtk-speech-rate rate )
      (setq dtk-speech-rate rate))
     (t (setq dtk-speech-rate rate)))
    (dtk-interp-set-rate rate)
    (when (ems-interactive-p )
      (message "Set speech rate to %s %s"
               rate
               (if prefix "" "locally")))))

;;;###autoload
(defun dtk-set-predefined-speech-rate (&optional prefix)
  "Set speech rate to one of nine predefined levels.
Interactive PREFIX arg says to set the rate globally.
Formula used is:
rate = dtk-speech-rate-base + dtk-speech-rate-step * level."
  (interactive "P")
  (declare (special dtk-speech-rate-step
                    dtk-speech-rate-base
                    last-input-event))
  (let ((level
         (condition-case nil
             (read (format "%c" last-input-event ))
           (error nil ))))
    (or (numberp level)
        (setq level
              (read-minibuffer "Enter level between 1 and 9 to set
speech rate:")))
    (cond
     ((or (not (numberp level))
          (< level 0)
          (> level  9))
      (error "Invalid level %s" level ))
     (t (dtk-set-rate
         (+ dtk-speech-rate-base
            (* dtk-speech-rate-step  level ))
         prefix )
        (when (ems-interactive-p )
          (message "Set speech rate to level %s"
                   level))))))

;;;###autoload
(defun dtk-set-character-scale (factor &optional prefix)
  "Set scale FACTOR for   speech rate.
Speech rate is scaled by this factor
when speaking characters.
Interactive PREFIX arg means set   the global default value, and then set the
current local  value to the result."
  (interactive "nEnter new factor:\nP")
  (declare (special dtk-character-scale dtk-speaker-process
                    dtk-speak-server-initialized))
  (when dtk-speak-server-initialized
    (cond
     (prefix
      (setq-default dtk-character-scale factor)
      (setq dtk-character-scale factor))
     (t (make-local-variable 'dtk-character-scale)
        (setq dtk-character-scale factor)))
    (dtk-interp-set-character-scale dtk-character-scale)
    (when (ems-interactive-p )
      (message "Set character scale factor to %s %s"
               dtk-character-scale
               (if  prefix ""  "locally")))))

(ems-generate-switcher 'dtk-toggle-quiet
                       'dtk-quiet
                       "Toggles state of  dtk-quiet.
Turning on this switch silences speech.
Optional interactive prefix arg causes this setting to become global.")

(ems-generate-switcher 'dtk-toggle-split-caps
                       'dtk-split-caps
                       "Toggle split caps mode.
Split caps mode is useful when reading
Hungarian notation in program source code.  Interactive PREFIX arg
means toggle the global default value, and then set the current local
value to the result.")

(ems-generate-switcher 'dtk-toggle-strip-octals
                       'tts-strip-octals
                       "Toggle stripping of octals.
Interactive prefix arg means
 toggle the global default value, and then set the current local
value to the result.")

(ems-generate-switcher' dtk-toggle-capitalization
                        'dtk-capitalize
                        "Toggle capitalization.
when set, capitalization is indicated by a
short beep.  Interactive PREFIX arg means toggle the global default
value, and then set the current local value to the result.")

(ems-generate-switcher' dtk-toggle-speak-nonprinting-chars
                        'dtk-speak-nonprinting-chars
                        "Toggle speak-nonprinting-chars.
Switches behavior of how characters with the high bit set are handled.
Interactive PREFIX arg means toggle the global default
value, and then set the current local value to the result.")

(ems-generate-switcher'dtk-toggle-allcaps-beep
 'dtk-allcaps-beep
 "Toggle allcaps-beep.
when set, allcaps words  are  indicated by a
short beep.  Interactive PREFIX arg means toggle the global default
value, and then set the current local value to the result.
Note that allcaps-beep is a very useful thing when programming.
However it is irritating to have it on when reading documents.")

(ems-generate-switcher 'dtk-toggle-debug
                       'dtk-debug
                       "Toggle state of the debug FLAG.
When debugging is on, you can switch to the buffer
*speaker* to examine the output from the process
that talks to the speech device by using command \\[tts-show-debug-buffer].
Note: *speaker* is a hidden buffer, ie it has a leading space in its name.")

;;;###autoload
(defun dtk-set-punctuations  (mode &optional prefix )
  "Set punctuation mode to MODE.
Possible values are `some', `all', or `none'.
Interactive PREFIX arg means set   the global default value, and then set the
current local  value to the result."
  (interactive
   (list
    (intern
     (completing-read  "Enter punctuation mode: "
                       dtk-punctuation-mode-alist
                       nil
                       t))
    current-prefix-arg))
  (declare (special dtk-punctuation-mode dtk-speaker-process
                    dtk-speak-server-initialized
                    dtk-punctuation-mode-alist))
  (when dtk-speak-server-initialized
    (cond
     (prefix
      (setq dtk-punctuation-mode mode )
      (setq-default dtk-punctuation-mode mode))
     (t (make-local-variable 'dtk-punctuation-mode)
        (setq dtk-punctuation-mode mode )))
    (dtk-interp-set-punctuations mode)
    (when (ems-interactive-p )
      (message "set punctuation mode to %s %s"
               mode
               (if prefix "" "locally")))))

;;;###autoload
(defun dtk-set-punctuations-to-all (&optional prefix )
  "Set punctuation  mode to all.
Interactive PREFIX arg sets punctuation mode globally."
  (interactive "P")
  (dtk-set-punctuations 'all prefix))

;;;###autoload
(defun dtk-set-punctuations-to-some (&optional prefix )
  "Set punctuation  mode to some.
Interactive PREFIX arg sets punctuation mode globally."
  (interactive "P")
  (dtk-set-punctuations 'some prefix))

;;;###autoload
(defun dtk-toggle-punctuation-mode (&optional prefix)
  "Toggle punctuation mode between \"some\" and \"all\".
Interactive PREFIX arg makes the new setting global."
  (interactive "P")
  (declare (special dtk-punctuation-mode))
  (cond
   ((eq 'all  dtk-punctuation-mode)
    (dtk-set-punctuations-to-some prefix ))
   ((eq 'some  dtk-punctuation-mode )
    (dtk-set-punctuations-to-all prefix )))
  (when (ems-interactive-p )
    (message "set punctuation mode to %s %s"
             dtk-punctuation-mode
             (if prefix "" "locally"))))

;;;###autoload
(defun dtk-reset-state ()
  "Restore sanity to the Dectalk.
Typically used after the Dectalk has been power   cycled."
  (interactive)
  (declare (special  dtk-speaker-process
                     dtk-speak-server-initialized))
  (when dtk-speak-server-initialized
    (dtk-interp-reset-state)))

;;;###autoload
(defun tts-speak-version ()
  "Speak version."
  (interactive)
  (dtk-interp-say-version))

;;}}}
;;{{{  pause and resume
(defvar dtk-paused nil
  "Records if speech has been paused.")

;;;###autoload
(defun dtk-pause ()
  "Temporarily pause / resume speech."
  (interactive)
  (declare (special dtk-paused))
  (cond
   ((not dtk-paused)
    (dtk-interp-pause)
    (setq dtk-paused t)
    (emacspeak-auditory-icon 'button))
   (t
    (setq dtk-paused nil)
    (dtk-interp-resume))))

;;;###autoload
(defcustom dtk-resume-should-toggle t
  "*T means `dtk-resume' acts as a toggle."
  :type 'boolean
  :group 'tts)

;;;###autoload
(defun dtk-resume ()
  "Resume paused speech.
This command resumes  speech that has been suspended by executing
command `dtk-pause' bound to \\[dtk-pause].
If speech has not been paused,
and option `dtk-resume-should-toggle' is set,
 then this command will pause ongoing speech."
  (interactive)
  (declare (special dtk-speaker-process
                    dtk-resume-should-toggle
                    dtk-paused))
  (cond
   ((and dtk-resume-should-toggle
         (not dtk-paused))
    (dtk-pause))
   ((and (not dtk-paused)
         (not dtk-resume-should-toggle))
    (dtk-speak "No speech to resume."))

   (t (dtk-interp-resume)
      (emacspeak-auditory-icon 'button)
      (setq dtk-paused nil))))

;;}}}
;;{{{  Internal variables:

(defvar dtk-stop-immediately t
  "If t, speech stopped immediately when new speech received.
Emacspeak sets this to nil if the current message being spoken is too
important to be interrupted.")

(defvar dtk-speaker-process nil
  "Speaker process handle.")
(defvar dtk-punctuation-mode  'all
  "Current setting of punctuation state.
Possible values are some, all or none.
You should not modify this variable;
Use command  `dtk-set-punctuations' bound to
\\[dtk-set-punctuations].  .")

(make-variable-buffer-local 'dtk-punctuation-mode)
;;; forward declaration
(defvar emacspeak-servers-directory
  (expand-file-name
   "servers/"
   emacspeak-directory))

(defun tts-setup-servers-alist ()
  "Sets up tts servers alist from file servers/.servers.
File .servers is expected to contain name of one server per
no line --with no white space."
  (declare (special emacspeak-servers-directory
                    dtk-servers-alist))
  (let ((result nil)
        (start nil)
        (scratch (get-buffer-create " *servers*"))
        (this nil))
    (save-current-buffer
      (set-buffer scratch)
      (setq buffer-undo-list t)
      (erase-buffer)
      (insert-file-contents
       (expand-file-name ".servers"
                         emacspeak-servers-directory))
      (goto-char (point-min))
      (while (not (eobp))
        (setq start (point))
        (unless
            (looking-at  "^#")
          (end-of-line)
          (setq this (buffer-substring-no-properties start (point)))
          (push this result))
        (forward-line 1)))
    (setq dtk-servers-alist result)))

(defvar dtk-servers-alist nil
  "Used for completion when prompting for TTS server.
This variable is automatically setup to reflect the
available TTS servers.")

;;}}}
;;{{{  Mapping characters to speech:

;;{{{ variable to hold buffer specific speech table

(defvar dtk-display-table nil
  "Variable holding display information for special characters.")

(make-variable-buffer-local 'dtk-display-table)

;;}}}
;;{{{  default speech table

(defvar dtk-character-to-speech-table
  (make-vector 256 "")
  "Maps characters to pronunciation strings.")
(declaim (special dtk-character-to-speech-table ))

;;;  Assign entries in the table:
(defun dtk-speak-setup-character-table ()
  "Setup pronunciations in the character table for the Dectalk."
  (let ((table dtk-character-to-speech-table))
    (aset  table 0 "control at")
    (aset  table 1 "control a")
    (aset  table 2 "control b")
    (aset  table 3  "control c")
    (aset  table 4 "control d")
    (aset  table 5 "control e")
    (aset  table 6 "control f")
    (aset  table 7 "control g")
    (aset  table 8 "control h")
    (aset  table 9 "tab")
    (aset  table 10 "newline")
    (aset  table 11 "control k")
    (aset  table 12 "control l")
    (aset  table 13 "control m")
    (aset  table 14 "control n")
    (aset  table 15 "control o")
    (aset  table 16"control p")
    (aset  table 17 "control q")
    (aset  table 18 "control r")
    (aset  table 19 "control s")
    (aset  table 20 "control t")
    (aset  table 21 "control u")
    (aset  table 22 "control v")
    (aset  table 23 "control w")
    (aset  table 24 "control x")
    (aset  table 25 "control y")
    (aset  table 26 "control z")
    (aset  table 27 "escape")
    (aset table 28 "control[*]backslash")
    (aset table 29 "control[*]right bracket")
    (aset table 30 "control[*]caret" )
    (aset table 31 "control[*]underscore")
    (aset table 32 "space")
    (aset table 33 "exclamation")
    (aset table 34 "quotes")
    (aset table 35  "pound")
    (aset table  36  "dollar")
    (aset table 37  "percent" )
    (aset table 38  "ampersand")
    (aset table 39  "apostrophe" )
    (aset table 40  "left[*]paren" )
    (aset table 41 "right[*]paren" )
    (aset table  42   "star")
    (aset table 43  "plus")
    (aset   table 44 "comma")
    (aset table  45  "dash")
    (aset table 46  "dot")
    (aset table 47  "slash")
    (aset table 48  "zero")
    (aset table 49 "one")
    (aset table 50 "two")
    (aset table 51 "three")
    (aset  table 52  "four")
    (aset  table 53 "five")
    (aset  table 54 "six")
    (aset  table 55 "seven")
    (aset  table 56 "eight")
    (aset  table 57 "nine")
    (aset table 58 "colon" )
    (aset table 59 "semi")
    1(aset table 60 "less[*]than")
    (aset  table 61 "equals")
    (aset  table 62  "greater[*]than")
    (aset  table 63 "question[*]mark")
    (aset  table 64 "at")
    (aset  table 65  " cap[*]a")
    (aset  table 66 " cap[*]b")
    (aset  table 67 "cap[*]c")
    (aset  table 68 "cap[*]d")
    (aset  table 69 "cap[*]e")
    (aset  table 70 "cap[*]f")
    (aset  table 71 "cap[*]g")
    (aset  table 72 "cap[*]h")
    (aset  table 73 "cap[*]i")
    (aset  table 74 "cap[*]j")
    (aset  table 75 "cap[*]k")
    (aset  table 76 "cap[*]l")
    (aset  table 77 "cap[*]m")
    (aset  table 78 "cap[*]m")
    (aset  table 79 "cap[*]o")
    (aset  table 80 "cap[*]p")
    (aset  table 81 "cap[*]q")
    (aset  table 82 "cap[*]r")
    (aset  table 83 "cap[*]s")
    (aset  table 84 "cap[*]t")
    (aset  table 85 "cap[*]u")
    (aset  table 86 "cap[*]v")
    (aset  table 87 "cap[*]w")
    (aset  table 88 "cap[*]x")
    (aset  table 89 "cap[*]y")
    (aset  table 90 "cap[*]z")
    (aset  table 91 "left[*]bracket")
    (aset  table 92  "backslash")
    (aset  table 93 "right[*]bracket")
    (aset  table 94  "caret")
    (aset  table 95  "underscore")
    (aset  table 96 "backquote")
    (aset  table 97  "a")
    (aset  table 98 "b")
    (aset  table 99 "c")
    (aset  table 100 "d")
    (aset  table 101 "e")
    (aset  table 102 "f")
    (aset  table 103 "g")
    (aset  table 104 "h")
    (aset  table 105 "i")
    (aset  table 106 "j")
    (aset  table 107 "k")
    (aset  table 108 "l")
    (aset  table 109 "m")
    (aset  table 110 "n")
    (aset  table 111 "o")
    (aset  table 112 "p")
    (aset  table 113 "q")
    (aset  table 114 "r")
    (aset  table 115 "s")
    (aset  table 116 "t")
    (aset  table 117 "u")
    (aset  table 118 "v")
    (aset  table 119 "w")
    (aset  table 120  "x")
    (aset  table 121 "y")
    (aset  table 122 "z")
    (aset  table 123 "left[*]brace")
    (aset  table 124 "pipe")
    (aset  table 125 "right[*]brace ")
    (aset  table 126 "tilde")
    (aset  table 127  "backspace")
;;; Characters with the 8th bit set:
    (aset  table 128  " octal 200 ")
    (aset  table 129  " ")              ;shows up on WWW pages
    (aset  table 130  " octal 202 ")
    (aset  table 131  " octal 203 ")
    (aset  table 132  " octal 204 ")
    (aset  table 133  " octal 205 ")
    (aset  table 134  " octal 206 ")
    (aset  table 135  " octal 207 ")
    (aset  table 136  " octal 210 ")
    (aset  table 137  " octal 211 ")
    (aset  table 138  " octal 212 ")
    (aset  table 139  " octal 213 ")
    (aset  table 140  " octal 214 ")
    (aset  table 141  " octal 215 ")
    (aset  table 142  " octal 216 ")
    (aset  table 143  " octal 217 ")
    (aset  table 144  " octal 220 ")
    (aset  table 145  " octal 221 ")
    (aset  table 146  " '  ")
    (aset  table 147  " quote  ")
    (aset  table 148  " octal 224 ")
    (aset  table 149  " octal 225 ")
    (aset  table 150  " octal 226 ")
    (aset  table 151  " octal 227 ")
    (aset  table 152  " octal 230 ")
    (aset  table 153  " octal 231 ")
    (aset  table 154  " octal 232 ")
    (aset  table 155  " octal 233 ")
    (aset  table 156  " octal 234 ")
    (aset  table 157  " octal 235 ")
    (aset  table 158  " octal 236 ")
    (aset  table 159  " octal 237 ")
    (aset  table 160  "  ")             ;non breaking space
    (aset  table 161  " octal 241 ")
    (aset  table 162  " octal 242 ")
    (aset  table 163  " octal 243 ")
    (aset  table 164  " octal 244 ")
    (aset  table 165  " octal 245 ")
    (aset  table 166  " octal 246 ")
    (aset  table 167  " octal 247 ")
    (aset  table 168  " octal 250 ")
    (aset  table 169  " copyright ")    ;copyright sign
    (aset  table 170  " octal 252 ")
    (aset  table 171  " octal 253 ")
    (aset  table 172  " octal 254 ")
    (aset  table 173  "-")              ;soft hyphen
    (aset  table 174  " (R) ")          ;registered sign
    (aset  table 175  " octal 257 ")
    (aset  table 176  " octal 260 ")
    (aset  table 177  " octal 261 ")
    (aset  table 178  " octal 262 ")
    (aset  table 179  " octal 263 ")
    (aset  table 180  " octal 264 ")
    (aset  table 181  " octal 265 ")
    (aset  table 182  " octal 266 ")
    (aset  table 183  " octal 267 ")
    (aset  table 184  " octal 270 ")
    (aset  table 185  " octal 271 ")
    (aset  table 186  " octal 272 ")
    (aset  table 187  " octal 273 ")
    (aset  table 188  " octal 274 ")
    (aset  table 189  " octal 275 ")
    (aset  table 190  " octal 276 ")
    (aset  table 191  " octal 277 ")
    (aset  table 192  " octal 300 ")
    (aset  table 193  " octal 301 ")
    (aset  table 194  " octal 302 ")
    (aset  table 195  " octal 303 ")
    (aset  table 196  " octal 304 ")
    (aset  table 197  " octal 305 ")
    (aset  table 198  " octal 306 ")
    (aset  table 199  " octal 307 ")
    (aset  table 200  " octal 310 ")
    (aset  table 201  " octal 311 ")
    (aset  table 202  " octal 312 ")
    (aset  table 203  " octal 313 ")
    (aset  table 204  " octal 314 ")
    (aset  table 205  " octal 315 ")
    (aset  table 206  " octal 316 ")
    (aset  table 207  " octal 317 ")
    (aset  table 208  " octal 320 ")
    (aset  table 209  " octal 321 ")
    (aset  table 210  " octal 322 ")
    (aset  table 211  " octal 323 ")
    (aset  table 212  " octal 324 ")
    (aset  table 213  " octal 325 ")
    (aset  table 214  " octal 326 ")
    (aset  table 215  " octal 327 ")
    (aset  table 216  " octal 330 ")
    (aset  table 217  " octal 331 ")
    (aset  table 218  " octal 332 ")
    (aset  table 219  " octal 333 ")
    (aset  table 220  " octal 334 ")
    (aset  table 221  " octal 335 ")
    (aset  table 222  " octal 336 ")
    (aset  table 223  " octal 337 ")
    (aset  table 224  " octal 340 ")
    (aset  table 225  " octal 341 ")
    (aset  table 226  " octal 342 ")
    (aset  table 227  " octal 343 ")
    (aset  table 228  " octal 344 ")
    (aset  table 229  " octal 345 ")
    (aset  table 230  " octal 346 ")
    (aset  table 231  " octal 347 ")
    (aset  table 232  " octal 350 ")
    (aset  table 233  " octal 351 ")
    (aset  table 234  " octal 352 ")
    (aset  table 235  " octal 353 ")
    (aset  table 236  " octal 354 ")
    (aset  table 237  " octal 355 ")
    (aset  table 238  " octal 356 ")
    (aset  table 239  " octal 357 ")
    (aset  table 240  " octal 360 ")
    (aset  table 241  " octal 361 ")
    (aset  table 242  " octal 362 ")
    (aset  table 243  " octal 363 ")
    (aset  table 244  " octal 364 ")
    (aset  table 245  " octal 365 ")
    (aset  table 246  " octal 366 ")
    (aset  table 247  " octal 367 ")
    (aset  table 248  " octal 370 ")
    (aset  table 249  " octal 371 ")
    (aset  table 250  " octal 372 ")
    (aset  table 251  " octal 373 ")
    (aset  table 252  " octal 374 ")
    (aset  table 253  " octal 375 ")
    (aset  table 254  " octal 376 ")
    (aset  table 255  " octal 377 ")))

(dtk-speak-setup-character-table)
;;}}}
;;{{{  iso ascii table:

(defvar dtk-iso-ascii-character-to-speech-table
  (and (boundp 'dtk-character-to-speech-table)
       (vectorp dtk-character-to-speech-table)
       (copy-sequence dtk-character-to-speech-table))
  "Table that records how ISO ascii characters are spoken.")

(let ((table dtk-iso-ascii-character-to-speech-table))
  (aset table 160 " no-break space ")
  (aset table 161 " inverted exclamation mark ")
  (aset table 162 " cent sign ")
  (aset table 163 " sterling ")
  (aset table 164 " general currency sign ")
  (aset table 165 " yen sign ")
  (aset table 166 " broken vertical line ")
  (aset table 167 " section sign ")
  (aset table 168 " diaeresis ")
  (aset table 169 " copyright sign ")
  (aset table 170 " ordinal indicator, feminine ")
  (aset table 171 " left angle quotation mark ")
  (aset table 172 " not sign ")
  (aset table 173 " soft hyphen ")
  (aset table 174 " registered sign ")
  (aset table 175 " macron ")
  (aset table 176 " degree sign ")
  (aset table 177 " plus or minus sign ")
  (aset table 178 " superscript two ")
  (aset table 179 " superscript three ")
  (aset table 180 " acute ")
  (aset table 181 " mu ")
  (aset table 182 " pilcrow ")
  (aset table 183 " middle dot ")
  (aset table 184 " cedilla ")
  (aset table 185 " superscript one ")
  (aset table 186 " ordinal indicator, masculine ")
  (aset table 187 " right angle quotation mark ")
  (aset table 188 " fraction one-quarter ")
  (aset table 189 " fraction one-half ")
  (aset table 190 " fraction three-quarters ")
  (aset table 191 " inverted question mark ")
  (aset table 192 " A graav ")
  (aset table 193 " A acute ")
  (aset table 194 " A circumflex ")
  (aset table 195 " A tilde ")
  (aset table 196 " A diaeresis ")
  (aset table 197 " A ring ")
  (aset table 198 " AE diphthong ")
  (aset table 199 " C cedilla ")
  (aset table 200 " E graav ")
  (aset table 201 " E acute ")
  (aset table 202 " E circumflex ")
  (aset table 203 " E diaeresis ")
  (aset table 204 " I graav ")
  (aset table 205 " I acute ")
  (aset table 206 " I circumflex ")
  (aset table 207 " I diaeresis ")
  (aset table 208 " D stroke, Icelandic eth ")
  (aset table 209 " N tilde ")
  (aset table 210 " O graav ")
  (aset table 211 " O acute ")
  (aset table 212 " O circumflex ")
  (aset table 213 " O tilde ")
  (aset table 214 " O diaeresis ")
  (aset table 215 " multiplication sign ")
  (aset table 216 " O slash ")
  (aset table 217 " U graav ")
  (aset table 218 " U acute ")
  (aset table 219 " U circumflex ")
  (aset table 220 " U diaeresis ")
  (aset table 221 " Y acute ")
  (aset table 222 " capital thorn, Icelandic ")
  (aset table 223 " small sharp s, German ")
  (aset table 224 " a graav ")
  (aset table 225 " a acute ")
  (aset table 226 " a circumflex ")
  (aset table 227 " a tilde ")
  (aset table 228 " a diaeresis ")
  (aset table 229 " a ring ")
  (aset table 230 " ae diphthong ")
  (aset table 231 " c cedilla ")
  (aset table 232 " e graav ")
  (aset table 233 " e acute ")
  (aset table 234 " e circumflex ")
  (aset table 235 " e diaeresis ")
  (aset table 236 " i graav ")
  (aset table 237 " i acute ")
  (aset table 238 " i circumflex ")
  (aset table 239 " i diaeresis ")
  (aset table 240 " d stroke, Icelandic eth ")
  (aset table 241 " n tilde ")
  (aset table 242 " o graav ")
  (aset table 243 " o acute ")
  (aset table 244 " o circumflex ")
  (aset table 245 " o tilde ")
  (aset table 246 " o diaeresis ")
  (aset table 247 " division sign ")
  (aset table 248 " o slash ")
  (aset table 249 " u graav ")
  (aset table 250 " u acute ")
  (aset table 251 " u circumflex ")
  (aset table 252 " u diaeresis ")
  (aset table 253 " y acute ")
  (aset table 254 " small thorn, Icelandic ")
  (aset table 255 " small y diaeresis ")
  )

;;}}}
(defsubst dtk-char-to-speech (char)
  "Translate CHAR to speech string."
  (declare (special dtk-character-to-speech-table))
  (if  (eq (char-charset char) 'ascii)
      (aref dtk-character-to-speech-table char )
    (or (dtk-unicode-short-name-for-char char)
        (format "octal %o"  char ))))

;;}}}
;;{{{  interactively selecting the server:

(defvar tts-voice-reset-code nil
  "Code sent to reset the voice to its default.
This is setup on a per engine basis.")

;;; will be reset on a per TTS engine basis.
(defalias 'tts-get-voice-command 'dectalk-get-voice-command)
;;;###autoload
(defun tts-configure-synthesis-setup (&optional tts-name)
  "Setup synthesis environment. "
  (declare (special dtk-program emacspeak-auditory-icon-function
                    tts-voice-reset-code))
  (unless tts-name (setq tts-name dtk-program))
  (cond
                                        ;viavoice outloud family 
   ((string-match "outloud" tts-name) (outloud-configure-tts))
                                        ;all dectalks
   ((string-match "dtk-" tts-name) (dectalk-configure-tts))
   ((string-match "^multispeech$" tts-name) (multispeech-configure-tts))
                                        ;exact match
   ((string-match "^mac$" tts-name) (mac-configure-tts))
                                        ; exact match
   ((string-match "^espeak$" tts-name) (espeak-configure-tts))
   ((string-match "^eflite$" tts-name) (flite-configure-tts))
   ((string-match "^log-server$" tts-name) t); use previous configuration
                                        ; generic configure
   (t (plain-configure-tts)))
  (when (string-match "^ssh" tts-name)  ;remote server
    (setq emacspeak-auditory-icon-function 'emacspeak-serve-auditory-icon))
  (load-library "voice-setup")
  (setq tts-voice-reset-code (tts-get-voice-command tts-default-voice)))

(defvar tts-device "default"
  "Name of current sound device in use.")

;;;###autoload
(defun dtk-select-server (program &optional device)
  "Select a speech server interactively.
Argument PROGRAM specifies the speech server program. When called
interactively, The selected server is started
immediately. Optional arg device sets up environment variable
ALSA_DEFAULT to specified device before starting the server."
  (interactive
   (list
    (completing-read
     "Select speech server:"
     (or dtk-servers-alist
         (tts-setup-servers-alist))
     nil
     t  )
    current-prefix-arg))
  (declare (special   dtk-program dtk-servers-alist
                      tts-device emacspeak-servers-directory
                      emacspeak-ssh-tts-server))
  (when (and (ems-interactive-p ) device)
    (setq tts-device (read-from-minibuffer "ALSA_DEFAULT: ")))
  (setenv "ALSA_DEFAULT" tts-device)
  (let ((ssh-server (format "ssh-%s" dtk-program)))
    (setq dtk-program program)
    (when (file-exists-p (expand-file-name ssh-server emacspeak-servers-directory))
      (setq emacspeak-ssh-tts-server ssh-server)
      (setq-default emacspeak-ssh-tts-server ssh-server))
    (when (ems-interactive-p )
      (dtk-initialize))))

(defcustom tts-device-list (list "default")
  "List of ALSA sound devices  we can use."
  :type '(repeat
          (choice :tag "Device"
                  (const   "default")
                  (const   "$ALSA_DEFAULT")
                  (string )))
  :group 'dtk)

;;;###autoload
(defun tts-cycle-device (&optional restart)
  "Cycle through available ALSA devices.
Optional interactive prefix arg restarts current TTS server."
  (interactive "P")
  (declare (special tts-device tts-device-list))
  (let ((pos (position tts-device tts-device-list :test
                       #'string=))
        (len (length tts-device-list)))
    (cond
     ((= len 1) (message "Only  one ALSA device."))
     (t                                 ; Cycle
      (setq tts-device
            (nth
             (% (+ 1 pos) len)
             tts-device-list))
      (setenv "ALSA_DEFAULT" tts-device)
      (message "ALSA_DEFAULT: %s" tts-device)
      (when current-prefix-arg (tts-restart))))))

(defvar dtk-async-server-process nil
  "Process handle to async server.")

;;;###autoload
(defun dtk-async-server (program)
  "Select and start an async  speech server interactively.
Async servers allow external programs like self-voicing Web browsers to use
the Emacspeak TTS server abstraction.
Argument PROGRAM specifies the speech server program."
  (interactive
   (list
    (completing-read
     "Select speech server:"
     (or dtk-servers-alist
         (tts-setup-servers-alist))
     nil
     t  )))
  (declare (special    dtk-servers-alist
                       dtk-async-server-process emacspeak-servers-directory ))
  (when (and
         dtk-async-server-process
         (eq 'run (process-status dtk-async-server-process)))
    (kill-process dtk-async-server-process))
  (setq dtk-async-server-process
        (start-process
         "AsyncTTS"
         "*AsyncTTS*"
         (executable-find "python")
         (expand-file-name "python/HTTPSpeaker.py" emacspeak-servers-directory)
         program)))

;;;###autoload
(defvar dtk-local-server-process nil
  "Local server process.")

;;;###autoload
(defcustom dtk-speech-server-program "speech-server"
  "Local speech server script."
  :type '(choice :tag "Local Server: "
                 (const :tag "32 Bit" "32-speech-server")
                 (const :tag "Default" "speech-server"))
  :group 'dtk)
(defvar dtk-local-server-port "2222"
  "Port where we run our local server.")

(defcustom dtk-local-engine "outloud"
  "Engine we use  for our local TTS  server."
  :type '(choice
          (const :tag "Dectalk Express" "dtk-exp")
          (const :tag "Viavoice Outloud" "outloud")
          (const :tag "32Bit ViaVoice on 64Bit Linux" "32-outloud"))
  :group 'dtk)

(defun dtk-local-server (program)
  "Select and start an local  speech server interactively.
Local server lets Emacspeak on a remote host connect back via SSH  port forwarding for instance.
Argument PROGRAM specifies the speech server program.
Port  defaults to  dtk-local-server-port"
  (interactive
   (list
    (completing-read
     "Select speech server:"
     (or dtk-servers-alist
         (tts-setup-servers-alist))
     nil
     t  )))
  (declare (special    dtk-servers-alist dtk-local-server-port
                       dtk-local-server-process emacspeak-servers-directory ))
  (when (and
         dtk-local-server-process
         (eq 'run (process-status dtk-local-server-process)))
    (kill-process dtk-async-server-process))
  (setq dtk-local-server-process
        (start-process
         "LocalTTS"
         "*localTTS*"
         (expand-file-name  dtk-speech-server-program emacspeak-servers-directory)
         dtk-local-server-port
         (expand-file-name program  emacspeak-servers-directory))))

;;}}}
;;{{{  initialize the speech process

(defvar dtk-debug nil
  "Set this to t if you want to debug the synthesizer server.")
(make-variable-buffer-local 'dtk-debug)

(defvar dtk-speak-server-initialized nil
  "Records if the server is initialized.")

(defvar tts-debug-buffer " *speaker*"
  "Buffer holding speech server debug output.")

(defun  dtk-initialize ()
  "Initialize speech system."
  (declare (special dtk-program tts-debug-buffer 
                    dtk-speaker-process  dtk-debug
                    dtk-speak-server-initialized
                    dtk-startup-hook emacspeak-servers-directory))
  (let ((new-process nil)
        (process-connection-type  nil))
    (setq new-process
          (apply 'start-process
                 "speaker"
                 (and dtk-debug tts-debug-buffer)
                 (expand-file-name dtk-program emacspeak-servers-directory)
                 dtk-program-args))
    (setq dtk-speak-server-initialized
          (or (eq 'run (process-status new-process ))
              (eq 'open (process-status new-process))))
    (cond
     (dtk-speak-server-initialized
      ;; nuke old server
      (when (and dtk-speaker-process
                 (or (eq 'run (process-status dtk-speaker-process ))
                     (eq 'open (process-status dtk-speaker-process ))
                     (eq 'stop (process-status dtk-speaker-process ))))
        (delete-process dtk-speaker-process ))
      (setq dtk-speaker-process new-process)
      (set-process-coding-system dtk-speaker-process 'utf-8 'utf-8)
      (run-hooks 'dtk-startup-hook ))
     (t
      (when (ems-interactive-p )
        (message "The speech server is not running."))))))

;;;###autoload
(defun tts-restart ()
  "Use this to nuke the currently running TTS server and restart it."
  (interactive)
  (dtk-initialize ))

;;;###autoload
(defun tts-show-debug-buffer ()
  "Select TTS debugging buffer."
  (interactive)
  (declare (special tts-debug-buffer))
  (switch-to-buffer tts-debug-buffer))

;;}}}
;;{{{  interactively select how text is split:

;;;###autoload
(defun dtk-toggle-splitting-on-white-space ()
  "Toggle splitting of speech on white space.
This affects the internal state of emacspeak that decides if we split
text purely by clause boundaries, or also include
whitespace.  By default, emacspeak sends a clause at a time
to the speech device.  This produces fluent speech for
normal use.  However in modes such as `shell-mode' and some
programming language modes, clause markers appear
infrequently, and this can result in large amounts of text
being sent to the speech device at once, making the system
unresponsive when asked to stop talking.  Splitting on white
space makes emacspeak's stop command responsive.  However,
when splitting on white space, the speech sounds choppy
since the synthesizer is getting a word at a time."
  (interactive)
  (declare (special dtk-chunk-separator-syntax))
  (cond
   ((not (string-match " " dtk-chunk-separator-syntax))
    (dtk-chunk-on-white-space-and-punctuations)
    (when (ems-interactive-p )
      (message "Text will be split at punctuations and white space when speaking") ))
   (t (dtk-chunk-only-on-punctuations)
      (when (ems-interactive-p )
        (message "Text split  at clause boundaries")))))

;;;###autoload
(defun dtk-set-chunk-separator-syntax (s)
  "Interactively set how text is split in chunks.
See the Emacs documentation on syntax tables for details on how characters are
classified into various syntactic classes.
Argument S specifies the syntax class."

  (interactive
   (list
    (read-from-minibuffer "Specify separator syntax string: ")))
  (declare (special dtk-chunk-separator-syntax))
  (setq dtk-chunk-separator-syntax s)
  (when (ems-interactive-p )
    (message "Set  separator to %s" s)))

;;}}}
;;{{{ speak text

(defun dtk-speak (text &optional ignore-skim)
  "Speak the TEXT string on the  tts.
This is achieved by sending the text to the speech server.
No-op if variable `dtk-quiet' is set to t.
If option `outline-minor-mode' is on and selective display is in effect,
only speak upto the first ctrl-m."
  (declare (special dtk-speaker-process dtk-stop-immediately
                    tts-strip-octals inhibit-point-motion-hooks
                    dtk-speak-server-initialized emacspeak-use-auditory-icons
                    dtk-speech-rate dtk-speak-nonprinting-chars
                    dtk-speak-treat-embedded-punctuations-specially
                    dtk-quiet  dtk-chunk-separator-syntax
                    voice-lock-mode   dtk-punctuation-mode
                    dtk-split-caps
                    emacspeak-pronounce-pronunciation-table
                    selective-display ))
                                        ; ensure text is a  string
  (unless (stringp text) (setq text (format "%s" text)))
                                        ; ensure  the process  is live
  (unless (or (eq 'run (process-status dtk-speaker-process ))
              (eq 'open (process-status dtk-speaker-process )))
    (dtk-initialize))
                                        ; If you dont want me to talk,
                                        ;or my server is not
                                        ;running, I will remain silent.
                                        ; Do nothing if text is ""
  (unless
      (or dtk-quiet
          (null text)
          (string-equal text "")
          (not dtk-speak-server-initialized))
                                        ; flush previous speech if asked to
    (when dtk-stop-immediately (dtk-stop ))
    (dtk-interp-sync)
    (or (stringp text) (setq text (format "%s" text )))
    (when selective-display
      (let ((ctrl-m (string-match "\015" text )))
        (and ctrl-m
             (setq text (substring  text 0 ctrl-m ))
             (emacspeak-auditory-icon 'ellipses))))
    (let ((inhibit-point-motion-hooks t)
          (deactivate-mark nil)
          (invisibility-spec buffer-invisibility-spec)
          (syntax-table (syntax-table ))
          (inherit-speaker-process dtk-speaker-process)
          (pronunciation-table emacspeak-pronounce-pronunciation-table)
          (use-auditory-icons emacspeak-use-auditory-icons)
          (inherit-chunk-separator-syntax dtk-chunk-separator-syntax )
          (inherit-speak-nonprinting-chars
           dtk-speak-nonprinting-chars)
          (inherit-strip-octals tts-strip-octals)
          (complement-separator(dtk-complement-chunk-separator-syntax ))
          (speech-rate dtk-speech-rate)
          (inherit-enable-multibyte-characters enable-multibyte-characters)
          (dtk-scratch-buffer (get-buffer-create " *dtk-scratch-buffer* "))
          (start 1)
          (end nil )
          (mode dtk-punctuation-mode)
          (split-caps dtk-split-caps)
          (voice-lock voice-lock-mode ))
      (save-current-buffer
        (set-buffer dtk-scratch-buffer )
        (setq buffer-undo-list t)
        (let ((inhibit-read-only t))
          (erase-buffer)
                                        ; inherit environment
          (setq buffer-invisibility-spec invisibility-spec
                dtk-chunk-separator-syntax inherit-chunk-separator-syntax
                dtk-speaker-process inherit-speaker-process
                dtk-speech-rate speech-rate
                emacspeak-use-auditory-icons use-auditory-icons
                dtk-punctuation-mode mode
                dtk-split-caps split-caps
                dtk-speak-nonprinting-chars
                inherit-speak-nonprinting-chars
                tts-strip-octals inherit-strip-octals
                voice-lock-mode voice-lock)
          (set-syntax-table syntax-table )
          (set-buffer-multibyte inherit-enable-multibyte-characters)
          (insert  text)
          (delete-invisible-text)
          (when pronunciation-table
            (tts-apply-pronunciations
             pronunciation-table))
          (dtk-unicode-replace-chars mode)
          (dtk-handle-repeating-patterns mode)
          (dtk-quote mode))
        (goto-char (point-min))
        (skip-syntax-forward inherit-chunk-separator-syntax)
        (while (and (not (eobp))
                    (dtk-move-across-a-chunk
                     inherit-chunk-separator-syntax
                     complement-separator))
                                        ;if we matched a punctuation,
                                        ;treat this as a chunk only if the punctuation is followed
                                        ;by white space
                                        ;dtk-speak-treat-embedded-punctuations-specially
                                        ;has been T for a long time
          (unless
              (and (char-after  (point))
                   (= (char-syntax (preceding-char )) ?.)
                   (not (= 32 (char-syntax (following-char )))))
            (setq end (point ))
            (dtk-format-text-and-speak  start end )
            (setq start  end)))         ; end while
                                        ; process trailing text
        (or  (= start (point-max))
             (dtk-format-text-and-speak start (point-max)))))
    (dtk-force)))

(defsubst dtk-speak-and-echo (message)
  "Speak message and echo it to the message area."
  (let ((emacspeak-speak-messages nil))
    (dtk-speak message) 
    (message message)))

(defun dtk-speak-list (text &optional group-count)
  "Speak a  list of strings.
Argument TEXT  is the list of strings to speak.
Optional argument group-count specifies grouping for intonation."
  (declare (special dtk-speaker-process))
  (let ((dtk-scratch-buffer (get-buffer-create " *dtk-scratch-buffer* "))
        (contents nil)
        (counter 1)
        (len (length text))
        (inhibit-read-only t))
    (save-current-buffer
      (set-buffer dtk-scratch-buffer )
      (setq buffer-undo-list t)
      (erase-buffer)
      (loop  for element in text
             do
             (insert
              (format "%s%s "
                      element
                      (cond
                       ((null group-count) "")
                       ((= len counter) ". ")
                       ((and group-count
                             (zerop (% counter group-count)))
                        ", ")
                       (t ""))))
             (incf counter))
      (setq contents (buffer-string)))
    (dtk-speak contents)))

(defsubst dtk-letter (letter)
  "Speak a LETTER."
  (declare (special dtk-speaker-process
                    dtk-speak-server-initialized
                    dtk-quiet ))
  (unless dtk-quiet
    (when dtk-speak-server-initialized
      (dtk-interp-letter  letter ))))
(defun dtk-say (words)
  "Say these WORDS."
  (declare (special dtk-speaker-process dtk-stop-immediately
                    dtk-speak-server-initialized dtk-quiet))
                                        ; ensure words is a  string
  (unless (stringp words) (setq words (format "%s" words)))
  ;; I wont talk if you dont want me to
  (unless
      (or dtk-quiet (string-equal words ""))
    (or (eq 'run (process-status dtk-speaker-process ))
        (eq 'open (process-status dtk-speaker-process ))
        (dtk-initialize))
    (when dtk-speak-server-initialized
      (and dtk-stop-immediately (dtk-stop ))
      (dtk-interp-say words))))

;;}}}
(provide 'dtk-speak)

;;{{{  emacs local variables

;;; local variables:
;;; folded-file: t
;;; byte-compile-dynamic: nil
;;; end:

;;}}}
