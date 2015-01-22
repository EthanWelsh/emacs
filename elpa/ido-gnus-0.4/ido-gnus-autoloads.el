;;; ido-gnus-autoloads.el --- automatically extracted autoloads
;;
;;; Code:


;;;### (autoloads (ido-gnus-select ido-gnus-select-server ido-gnus-select-group)
;;;;;;  "ido-gnus" "ido-gnus.el" (21155 35115 581045 807000))
;;; Generated autoloads from ido-gnus.el

(autoload 'ido-gnus-select-group "ido-gnus" "\
Select a gnus group to visit using ido.
If a prefix arg is used then the sense of `ido-gnus-num-articles' will be reversed:
  if it is a number then the number of articles to display will be prompted for,
otherwise `gnus-large-newsgroup' articles will be displayed.

gnus will be started if it is not already running.

\(fn PREFIX)" t nil)

(autoload 'ido-gnus-select-server "ido-gnus" "\
Select a gnus server to visit using ido.

gnus will be started if it is not already running.

\(fn)" t nil)

(autoload 'ido-gnus-select "ido-gnus" "\
Select a gnus group/server or existing gnus buffer using ido.

\(fn PREFIX)" t nil)

;;;***

;;;### (autoloads nil nil ("ido-gnus-pkg.el") (21155 35115 634247
;;;;;;  869000))

;;;***

(provide 'ido-gnus-autoloads)
;; Local Variables:
;; version-control: never
;; no-byte-compile: t
;; no-update-autoloads: t
;; coding: utf-8
;; End:
;;; ido-gnus-autoloads.el ends here
