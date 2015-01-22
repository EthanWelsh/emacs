;;; g-cus-load.el --- automatically extracted custom dependencies
;;
;;; Code:

(put 'applications 'custom-loads '(g))
(put 'g 'custom-loads '(g-auth g-utils gblogger gbooks gcal gcontacts gdocs gfeeds ghealth gmaps gnotebook gphoto gsheet gskeleton gtube gweb))
(put 'g-auth 'custom-loads '(g-auth))
(put 'gblogger 'custom-loads '(gblogger))
(put 'gbooks 'custom-loads '(gbooks))
(put 'gcal 'custom-loads '(gcal))
(put 'gcontacts 'custom-loads '(gcontacts))
(put 'gdocs 'custom-loads '(gdocs))
(put 'gfeeds 'custom-loads '(gfeeds))
(put 'ghealth 'custom-loads '(ghealth))
(put 'gmaps 'custom-loads '(gmaps))
(put 'gnotebook 'custom-loads '(gnotebook))
(put 'gphoto 'custom-loads '(gphoto))
(put 'gsheet 'custom-loads '(gsheet))
(put 'gskeleton 'custom-loads '(gskeleton))
(put 'gtube 'custom-loads '(gtube))
(put 'gweb 'custom-loads '(gmaps))
(put 'gwis 'custom-loads '(gwis))

;; The remainder of this file is for handling :version.
;; We provide a minimum of information so that `customize-changed-options'
;; can do its job.

;; For groups we set `custom-version', `group-documentation' and
;; `custom-tag' (which are shown in the customize buffer), so we
;; don't have to load the file containing the group.

;; This macro is used so we don't modify the information about
;; variables and groups if it's already set. (We don't know when
;; g-cus-load.el is going to be loaded and at that time some of the
;; files might be loaded and some others might not).
(defmacro custom-put-if-not (symbol propname value)
  `(unless (get ,symbol ,propname)
     (put ,symbol ,propname ,value)))


(defvar custom-versions-load-alist nil
  "For internal use by custom.
This is an alist whose members have as car a version string, and as
elements the files that have variables or faces that contain that
version.  These files should be loaded before showing the customization
buffer that `customize-changed-options' generates.")


(provide 'g-cus-load)
;; Local Variables:
;; version-control: never
;; no-byte-compile: t
;; no-update-autoloads: t
;; coding: utf-8
;; End:
;;; g-cus-load.el ends here
