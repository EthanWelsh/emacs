;;; emacspeak-websearch.el --- search utilities
;;; $Id: emacspeak-websearch.el 8367 2013-07-02 15:57:23Z tv.raman.tv $
;;; $Author: tv.raman.tv $
;;; Description:  Emacspeak extension to make Web searching convenient
;;; Keywords: Emacspeak, WWW interaction
;;{{{  LCD Archive entry:

;;; LCD Archive Entry:
;;; emacspeak| T. V. Raman |raman@cs.cornell.edu
;;; A speech interface to Emacs |
;;; $Date: 2008-08-14 11:23:31 -0700 (Thu, 14 Aug 2008) $ |
;;;  $Revision: 4625 $ |
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

;;{{{ required modules

(require 'emacspeak-preamble)
(require 'emacspeak-webutils)
(require 'emacspeak-google)
(require 'gweb)
(require  'emacspeak-we)
(require 'calendar)

;;}}}
;;{{{  Introduction:

;;; Commentary:

;;; This module provides utility functions for searching the WWW

;;; Code:

;;}}}
;;{{{ Forward Declarations:

(defvar emacspeak-xslt-directory)
(defvar emacspeak-wizards-personal-portfolio)

(declare-function gweb-google-autocomplete (&optional prompt))
(declare-function gtube-video-by-tag(tag &optional page count))
(declare-function calendar-astro-date-string (&optional date))
;;}}}
;;{{{ searcher table
;;;###autoload
(defgroup emacspeak-websearch nil
  "Websearch tools for the Emacspeak desktop."
  :group 'emacspeak)
(defvar emacspeak-websearch-table (make-hash-table)
  "Table holding mapping from search engine names to appropriate searcher functions.")

(defsubst emacspeak-websearch-set-searcher  (engine searcher)
  (declare (special emacspeak-websearch-table))
  (setf (gethash engine emacspeak-websearch-table) searcher))

(defsubst emacspeak-websearch-get-searcher (engine)
  (declare (special emacspeak-websearch-table))
  (gethash engine emacspeak-websearch-table))

;;}}}
;;{{{ Key table

(defvar emacspeak-websearch-keytable (make-hash-table)
  "Table holding mapping from keys to appropriate search engine names.")

(defsubst emacspeak-websearch-set-key  (key engine)
  (declare (special emacspeak-websearch-keytable))
  (setf (gethash key emacspeak-websearch-keytable) engine))

(defsubst emacspeak-websearch-get-engine (key)
  (declare (special emacspeak-websearch-keytable))
  (gethash key emacspeak-websearch-keytable))

;;}}}
;;{{{ top-level dispatch
;;;###autoload
(defun emacspeak-websearch-help ()
  "Displays key mapping used by Emacspeak Websearch."
  (interactive)
  (let ((map (loop for key being the hash-keys of
                   emacspeak-websearch-keytable
                   collect
                   (cons key (gethash key emacspeak-websearch-keytable)))))
    (setq map (sort map
                    #'(lambda (a b)
                        (< (car a)
                           (car b)))))
    (with-output-to-temp-buffer "*Help*"
      (save-excursion
        (set-buffer "*Help*")
        (princ "Websearch Keys:\n\n")
        (loop for m in map
              do
              (princ (key-description (list (car m))))
              (move-to-column 16 )
              (princ "`")
              (princ (emacspeak-websearch-get-searcher (cdr m)))
              (princ "'")
              (princ "\n"))
        (help-setup-xref
         (list #'emacspeak-websearch-help)
         (ems-interactive-p ))))
    (pop-to-buffer "*Help*")
    (help-mode)
    (goto-char (point-min))
    (emacspeak-speak-line)
    (emacspeak-auditory-icon 'help)))

(emacspeak-websearch-set-searcher  'help
                                   'emacspeak-websearch-help)

(emacspeak-websearch-set-key ?? 'help)
;;;###autoload
(defun emacspeak-websearch-dispatch  (&optional prefix)
  " Press `?' to list available search engines.
When using supported browsers,  this interface attempts to speak the most relevant information on the result page."
  (interactive "P")
  (let ((engine nil)
        (searcher nil))
    (while (null engine)
      (setq engine
            (emacspeak-websearch-get-engine
             (read-char
              (concat "Websearch? "
                      (documentation this-command))))))
    (setq searcher (emacspeak-websearch-get-searcher engine))
    (if searcher
        (call-interactively searcher)
      (error "I do not know how to search using %s" engine))))

;;}}}
;;{{{ helpers

;;{{{ helpers to read the query

(defvar emacspeak-websearch-history nil
  "Holds history of search queries.")

(defsubst emacspeak-websearch-read-query (prompt &optional
                                                 default
                                                 initial )
  (let ((answer
         (read-from-minibuffer
          prompt
          initial  nil nil
          (car emacspeak-websearch-history)
          (or default (word-at-point)))))
    (pushnew answer  emacspeak-websearch-history :test
             #'string-equal)
    answer))

;;}}}
;;{{{ post processer hook

;;}}}

;;}}}
;;{{{ websearch utilities

;;{{{ display form

(emacspeak-websearch-set-searcher 'display-form
                                  'emacspeak-websearch-display-form)

(emacspeak-websearch-set-key ?/ 'display-form)

(defun emacspeak-websearch-display-form (form-markup)
  "Display form specified by form-markup."
  (interactive
   (list
    (let ((emacspeak-speak-messages nil))
      (emacspeak-pronounce-define-local-pronunciation
       (expand-file-name "xml-forms"
                         emacspeak-lisp-directory)
       " xml forms ")
      (read-file-name "Display Form: "
                      (expand-file-name "xml-forms/" emacspeak-lisp-directory)))))
  (declare (special emacspeak-we-xsl-p
                    emacspeak-web-post-process-hook
                    emacspeak-lisp-directory))
  (let ((buffer (get-buffer-create " *search-form*"))
        (emacspeak-we-xsl-p nil))
    (save-excursion
      (set-buffer buffer)
      (erase-buffer)
      (kill-all-local-variables)
      (insert-file-contents  form-markup)
      (add-hook 'emacspeak-web-post-process-hook
                #'(lambda ()
                    (goto-char (point-min))
                    (widget-forward 1)
                    (emacspeak-auditory-icon 'open-object)
                    (emacspeak-widget-summarize (widget-at (point)))))
      (browse-url-of-buffer)
      (kill-buffer buffer))))

;;}}}
;;{{{ Computer Science Bibliography

(emacspeak-websearch-set-searcher 'biblio
                                  'emacspeak-websearch-biblio-search)

(emacspeak-websearch-set-key 2 'biblio)

(defvar emacspeak-websearch-biblio-uri
  "http://liinwww.ira.uka.de/searchbib/index?partial=on&case=on&results=citation&maxnum=200&query="
  "URI to search the Computer Science Bibliographies.")

;;;###autoload
(defun emacspeak-websearch-biblio-search (query)
  "Search Computer Science Bibliographies."
  (interactive
   (list
    (emacspeak-websearch-read-query "Search CS Bibliographies  for: ")))
  (declare (special emacspeak-websearch-biblio-uri))
  (browse-url
   (concat emacspeak-websearch-biblio-uri
           (emacspeak-url-encode query)))
  (emacspeak-webutils-post-process
   query
   'emacspeak-speak-line))

;;}}}
;;{{{ CiteSeer Citation index

(defvar emacspeak-websearch-citeseer-uri
  "http://citeseer.nj.nec.com/cs?"
  "URI for searching CiteSeer index. ")

(defvar emacspeak-websearch-citeseer-citation-options
  "cs=1&submit=Search+Citations&cf=Any&co=Citations&cm=50"
  "* Options for performing a citation search on CiteSeer.")

(defvar emacspeak-websearch-citeseer-article-options
  "cs=1&cf=Author&co=Citations&cm=50&submit=Search+Indexed+Articles&af=Any&ao=Citations&am=50"
  "* Options for performing an article search on CiteSeer. ")

(emacspeak-websearch-set-searcher 'citeseer

                                  'emacspeak-websearch-citeseer-search)

(emacspeak-websearch-set-key 3 'citeseer)

;;;###autoload
(defun emacspeak-websearch-citeseer-search(term )
  "Perform a CiteSeer search. "
  (interactive
   (list
    (emacspeak-websearch-read-query
     "Enter CiteSeer query term:")))
  (declare (special emacspeak-websearch-citeseer-uri
                    emacspeak-websearch-citeseer-citation-options
                    emacspeak-websearch-citeseer-article-options))
  (let ((options nil)
        (type-char
         (read-char
          "a Articles c Citations")))
    (setq options
          (case type-char
            (?a
             emacspeak-websearch-citeseer-article-options)
            (?c emacspeak-websearch-citeseer-citation-options)))
    (browse-url
     (concat emacspeak-websearch-citeseer-uri
             "q="
             (emacspeak-url-encode term)
             "&"
             options))
    (cond
     ((char-equal type-char ?a)
      (emacspeak-webutils-post-process "documents found"
                                       'emacspeak-speak-line))
     ((char-equal ?c type-char)
      (emacspeak-webutils-post-process "citations found" 'emacspeak-speak-line)))))

;;}}}
;;{{{ BlinkX

(emacspeak-websearch-set-searcher 'blinkx
                                  'emacspeak-websearch-blinkx-search)

(emacspeak-websearch-set-key ?B 'blinkx)

(defvar emacspeak-websearch-blinkx-uri
  "http://emea-store.blinkx.com/redirectors/SmartFeed.php?max=50&channel=reuters+revs+fox+webvideo+theonenetwork+verdictoncars+londontv+totalvid+inthebox+transmission+ifilms2+cspan+cspan2+bbcxml+bloomberg+cnn+itv+msnbc+forbes+podcast&siteId=3&oId=2100-1032-5793745&ontId=1023&lop=nl.ex&q="
  "URI to search  BlinkX for broadcasts.")

;;;###autoload
(defun emacspeak-websearch-blinkx-search (query)
  "BlinkX RSS Generator."
  (interactive
   (list
    (emacspeak-websearch-read-query "Search Online Broadcasts for: ")))
  (declare (special emacspeak-websearch-blinkx-uri))
  (emacspeak-webutils-rss-display
   (concat  emacspeak-websearch-blinkx-uri
            (emacspeak-url-encode query))))

;;}}}
;;{{{ FolDoc

(emacspeak-websearch-set-searcher 'foldoc
                                  'emacspeak-websearch-foldoc-search)
(emacspeak-websearch-set-key ?f 'foldoc)

(defvar emacspeak-websearch-foldoc-uri
  "http://wombat.doc.ic.ac.uk/foldoc/"
  "*URI for launching a FolDoc  search.")

;;;###autoload
(defun emacspeak-websearch-foldoc-search (query)
  "Perform a FolDoc search. "
  (interactive
   (list
    (emacspeak-websearch-read-query "Computing Dictionary Query: ")))
  (declare (special emacspeak-websearch-foldoc-uri))
  (browse-url
   (concat emacspeak-websearch-foldoc-uri
           (emacspeak-url-encode query)))
  (emacspeak-webutils-post-process
   query
   'emacspeak-speak-line))

;;}}}
;;{{{ quotes from yahoo

(emacspeak-websearch-set-searcher 'quotes-yahoo
                                  'emacspeak-websearch-quotes-yahoo-search)

(emacspeak-websearch-set-key ?q 'quotes-yahoo)

(defvar emacspeak-websearch-quotes-yahoo-uri
  "http://finance.yahoo.com/q?s="
  "*URI for launching a Yahoo Quotes  search.")

(defvar emacspeak-websearch-quotes-csv-yahoo-uri
  "http://quote.yahoo.com/d/quotes.csv?f=snl1d1t1c1p2va2bapomwerr1dyj1x&s="
  "*URI for launching a Yahoo Quotes  search.
See http://www.gummy-stuff.org/Yahoo-data.htm and Perl module Finance::Yahoo")

(defvar emacspeak-websearch-quotes-yahoo-options
  "&d=v1"
  "*Additional default options to pass to Yahoo.")

(defvar emacspeak-websearch-curl-program "curl"
  "Name of curl executable")

;;;###autoload
(defun emacspeak-websearch-quotes-yahoo-search (query &optional prefix)
  "Perform a Quotes Yahoo .
Default tickers to look up is taken from variable
emacspeak-wizards-personal-portfolio.
Default is to present the data in emacspeak's table browsing
mode --optional interactive prefix arg
causes data to be displayed as  a Web page.
You can customize the defaults by setting variable
emacspeak-websearch-quotes-yahoo-options to an appropriate string."
  (interactive
   (list
    (emacspeak-websearch-read-query "Lookup quotes: "
                                    emacspeak-wizards-personal-portfolio
                                    emacspeak-wizards-personal-portfolio)
    current-prefix-arg))
  (declare (special emacspeak-websearch-quotes-yahoo-uri
                    emacspeak-wizards-personal-portfolio
                    emacspeak-websearch-quotes-yahoo-options
                    emacspeak-websearch-curl-program
                    emacspeak-websearch-quotes-csv-yahoo-uri))
  (cond
   ((null prefix)
    (let ((uri (concat emacspeak-websearch-quotes-csv-yahoo-uri
                       (emacspeak-url-encode (format "%s" query))))
          (results "*quotes-table*")
          (process nil))
;;; nuke old results if any
      (when (get-buffer results )
        (kill-buffer results))
      (setq process
            (start-process   "lynx"
                             results
                             emacspeak-websearch-curl-program
                             "--silent"
                             uri))
      (set-process-sentinel process 'emacspeak-websearch-view-csv-data)))
   (t
    (browse-url
     (concat emacspeak-websearch-quotes-yahoo-uri
             (emacspeak-url-encode query)
             emacspeak-websearch-quotes-yahoo-options))
    (emacspeak-webutils-post-process
     "Symbol"
     'emacspeak-speak-line))))

;;}}}
;;{{{ Lookup company news at Yahoo

(emacspeak-websearch-set-searcher 'company-news
                                  'emacspeak-websearch-company-news)
(emacspeak-websearch-set-key ?c 'company-news)

(defvar emacspeak-websearch-company-news-uri
  "http://finance.yahoo.com/q"
  "*URI for launching a company news lookup")

(defvar emacspeak-websearch-yahoo-charts-uri
  "http://chart.yahoo.com/t?"
  "*URI for locating historical chart data.")

(defvar emacspeak-websearch-yahoo-csv-charts-uri
  "http://itable.finance.yahoo.com/table.csv?"
  "*URI for locating historical chart data.")

(defvar emacspeak-websearch-yahoo-company-news-quotes-uri
  "http://finance.yahoo.com/q?d=t&o=t"
  "URI for looking up detailed quote information. ")

;;;###autoload
(defun emacspeak-websearch-company-news (ticker &optional prefix)
  "Perform an company news lookup.
Retrieves company news, research, profile, insider trades,  or upgrades/downgrades."
  (interactive
   (list
    (emacspeak-websearch-read-query
     "Enter stock ticker of company to lookup: ")
    current-prefix-arg))
  (declare (special emacspeak-websearch-company-news-uri))
  (let ((type-char
         (read-char
          "b basic, c Upgrades, h history, i insider, n news, o options, r Research, p profile, q Quotes, t technical")))
    (cond
     ((char-equal type-char ?h)
      (emacspeak-websearch-yahoo-historical-chart ticker prefix)
      (emacspeak-auditory-icon 'select-object)
      (message "Fetching data --just a minute."))
     (t
      (browse-url
       (concat emacspeak-websearch-company-news-uri
               (format "%s?"
                       (case type-char
                         (?n "/h")
                         (?p "/pr")
                         (?r "/ae")
                         (?c "/ao")
                         (?i "/it")
                         (?q "")
                         (?k "/ks")
                         (?b "/bc")
                         (?t "/ta")
                         (?e "/ce")
                         (?o "/op")
                         (?s "/sec")))
               (format "s=%s" ticker)))
      (emacspeak-webutils-post-process
       (format-time-string "%Y")
       'emacspeak-speak-line)))))

(defun emacspeak-websearch-view-csv-data (process state )
  "Process csv data and put it in emacspeak table mode. "
  (message "state: %s" state)
  (when (string-match "^finished" state)
    (emacspeak-auditory-icon 'select-object)
    (emacspeak-table-view-csv-buffer (process-buffer process))))

;;;###autoload
(defun emacspeak-websearch-yahoo-historical-chart (ticker
                                                   &optional as-html)
  "Look up historical stock data.
Optional second arg as-html processes the results as HTML rather than data."
  (interactive
   (list
    (emacspeak-websearch-read-query "Stock ticker:")
    current-prefix-arg))
  (declare (special emacspeak-websearch-curl-program
                    emacspeak-websearch-yahoo-charts-uri
                    emacspeak-websearch-yahoo-csv-charts-uri))
  (let ((start-month
         (read-from-minibuffer "Start Month: "
                               (format-time-string "%m")))
        (start-date
         (read-from-minibuffer "Start Date: "
                               (format-time-string  "%d")))
        (start-year
         (read-from-minibuffer "Start Year: "
                               (format-time-string "%y")))
        (end-month
         (read-from-minibuffer "End Month: "
                               (format-time-string "%m")))
        (end-date (read-from-minibuffer "End Date: "
                                        (format-time-string
                                         "%d")))
        (end-year
         (read-from-minibuffer "End Year: "
                               (format-time-string "%y")))
        (period
         (format "%c"
                 (read-char
                  "Daily: d Weekly: w Monthly: m"))))
    (cond
     ((not as-html)
      (let ((uri (concat emacspeak-websearch-yahoo-csv-charts-uri
                         (format "a=%s" start-month)
                         (format "&b=%s" start-date)
                         (format "&c=%s" start-year)
                         (format "&d=%s" end-month)
                         (format "&e=%s" end-date)
                         (format "&f=%s" end-year)
                         (format "&g=%s" period)
                         (format "&s=%s" ticker)
                         "&q=q&x=.csv"))
            (results (format "*%s*" ticker))
            (process nil))
        (setq process
              (start-process   "curl"
                               results
                               emacspeak-websearch-curl-program
                               "--silent" "--location"
                               uri))
        (set-process-sentinel process 'emacspeak-websearch-view-csv-data)))
     (t (browse-url
         (concat emacspeak-websearch-yahoo-charts-uri
                 (format "a=%s" start-month)
                 (format "&b=%s" start-date)
                 (format "&c=%s" start-year)
                 (format "&d=%s" end-month)
                 (format "&e=%s" end-date)
                 (format "&f=%s" end-year)
                 (format "&g=%s" period)
                 (format "&s=%s" ticker)))
        (emacspeak-webutils-post-process
         "Open"
         'emacspeak-speak-line)))))

;;}}}
;;{{{  usenet

(emacspeak-websearch-set-searcher 'dejanews
                                  'emacspeak-websearch-usenet-search)

(emacspeak-websearch-set-key ?D 'dejanews)

;;;###autoload
(defun emacspeak-websearch-usenet-search (group)
  "Search a Usenet newsgroup."
  (interactive
   (list
    (read-from-minibuffer "Newsgroup search: ")))
  (emacspeak-websearch-usenet group 'search))

;;}}}
;;{{{ source forge

(emacspeak-websearch-set-searcher 'software
                                  'emacspeak-websearch-software-search)

(emacspeak-websearch-set-key ?s 'software)

(defvar emacspeak-websearch-sourceforge-search-uri
  "http://sourceforge.net/search/?"
  "URI for searching the SourceForge site.")

;;;###autoload
(defun emacspeak-websearch-sourceforge-search (query)
  "Search SourceForge Site. "
  (interactive
   (list
    (emacspeak-websearch-read-query "Search SourceForge for: ")))
  (declare (special emacspeak-websearch-sourceforge-search-uri))
  (emacspeak-we-extract-table-by-match "Description"
                                       (concat
                                        emacspeak-websearch-sourceforge-search-uri
                                        "type_of_search=soft"
                                        "&exact=1"
                                        "&words="
                                        (emacspeak-url-encode query))))

(defvar emacspeak-websearch-freshmeat-search-uri
  "http://www.freshmeat.net/search?q="
  "URI for searching Freshmeat site. ")

;;;###autoload
(defun emacspeak-websearch-freshmeat-search (query)
  "Search Freshmeat  Site. "
  (interactive
   (list
    (emacspeak-websearch-read-query "Search Freshmeat  for: ")))
  (declare (special emacspeak-websearch-freshmeat-search-uri))
  (browse-url
   (concat emacspeak-websearch-freshmeat-search-uri
           (emacspeak-url-encode query)))
  (emacspeak-webutils-post-process
   "search results"
   'emacspeak-speak-line))

(defvar emacspeak-websearch-ctan-search-uri
  "http://www.ctan.org/tools/filesearch?action=/search/&filename="
  "URI for searching CTAN archives for tex and latex utilities. ")

;;;###autoload
(defun emacspeak-websearch-ctan-search (query)
  "Search CTAN Comprehensive TeX Archive Network   Site. "
  (interactive
   (list
    (emacspeak-websearch-read-query
     "Lookup Comprehensive TEX Archive for: ")))
  (declare (special emacspeak-websearch-ctan-search-uri))
  (browse-url
   (concat emacspeak-websearch-ctan-search-uri
           (emacspeak-url-encode query)))
  (emacspeak-webutils-post-process
   query
   'emacspeak-speak-line))

(defvar emacspeak-websearch-cpan-search-uri
  "http://search.cpan.org/search?mode=module&query="
  "URI for searching CPAN  archives for perl modules . ")

;;;###autoload
(defun emacspeak-websearch-cpan-search (query)
  "Search CPAN  Comprehensive Perl Archive Network   Site. "
  (interactive
   (list
    (emacspeak-websearch-read-query
     "Locate PERL Module: ")))
  (declare (special emacspeak-websearch-cpan-search-uri))
  (browse-url
   (concat emacspeak-websearch-cpan-search-uri
           (emacspeak-url-encode query)))
  (emacspeak-webutils-post-process
   query
   'emacspeak-speak-line))
(defvar emacspeak-websearch-swik-search-uri
  "http://www.swik.net/project/"
  "URI for locating project communities via swik.")

;;;###autoload
(defun emacspeak-websearch-swik-search (query)
  "Search swik software community site."
  (interactive
   (list
    (emacspeak-websearch-read-query
     "SWIK Query:")))
  (declare (special emacspeak-websearch-swik-search-uri))
  (browse-url
   (concat emacspeak-websearch-swik-search-uri
           (emacspeak-url-encode query)))
  (emacspeak-webutils-post-process
   query
   'emacspeak-speak-line))

(defvar emacspeak-websearch-software-sites
  "f FreshMeat p Perl s SourceForge t TEX cap S SWIK"
  "Sites searched for open source software. ")

;;; top level dispatcher for searching source locations
;;;###autoload
(defun emacspeak-websearch-software-search  ()
  "Search SourceForge, Freshmeat and other sites. "
  (interactive)
  (declare (special emacspeak-websearch-software-sites))
  (let ((site
         (read-char emacspeak-websearch-software-sites)))
    (case site
      (?f (call-interactively 'emacspeak-websearch-freshmeat-search))
      (?p (call-interactively 'emacspeak-websearch-cpan-search))
      (?s (call-interactively 'emacspeak-websearch-sourceforge-search))
      (?t (call-interactively 'emacspeak-websearch-ctan-search))
      (?S (call-interactively 'emacspeak-websearch-swik-search))
      (otherwise (message emacspeak-websearch-software-sites )))))

;;}}}
;;{{{ Gutenberg

(emacspeak-websearch-set-searcher 'gutenberg
                                  'emacspeak-websearch-gutenberg)
(emacspeak-websearch-set-key ?G 'gutenberg)

(defvar emacspeak-websearch-gutenberg-uri
  "http://digital.library.upenn.edu/webbin/book/search?"
  "*URI for Gutenberg search")

;;;###autoload
(defun emacspeak-websearch-gutenberg (type query)
  "Perform an Gutenberg search"
  (interactive
   (list
    (read-char "Author a, Title t")
    (emacspeak-websearch-read-query "Gutenberg query: ")))
  (declare (special emacspeak-websearch-gutenberg-uri))
  (browse-url
   (concat emacspeak-websearch-gutenberg-uri
           (ecase type
             (?a "author=")
             (?t "title="))
           (emacspeak-url-encode query)))
  (emacspeak-webutils-post-process
   query
   'emacspeak-speak-line))

;;}}}
;;{{{ google
;;;###autoload
(defcustom emacspeak-websearch-google-use-https t
  "Specify whether we use secure connections for Google search."
  :type 'boolean
  :group 'emacspeak-websearch)

(emacspeak-websearch-set-searcher 'realtime-google
                                  'emacspeak-google-realtime-search)
(emacspeak-websearch-set-key ?R 'realtime-google)

(emacspeak-websearch-set-searcher 'google
                                  'emacspeak-websearch-google)
(emacspeak-websearch-set-key ?g 'google)
(emacspeak-websearch-set-key ?i 'google)

;;;###autoload
(defcustom emacspeak-websearch-google-number-of-results 25
  "Number of results to return from google search."
  :type 'number
  :group 'emacspeak-websearch)
(defcustom emacspeak-websearch-google-results-only t
  "Specify if we show just results or the complete Google page."
  :type  'boolean
  :group 'emacspeak-websearch)

(defvar emacspeak-websearch-google-uri-template
  "www.google.com/search?source=hp&q="
  "*URI for Google search")

(defsubst emacspeak-websearch-google-uri ()
  "Return URI end-point for Google search."
  (declare (special emacspeak-websearch-google-use-https
                    emacspeak-websearch-google-uri-template))
  (concat
   (if emacspeak-websearch-google-use-https
       "https://"
     "http://")
   emacspeak-websearch-google-uri-template))

(defcustom emacspeak-websearch-google-options nil
  "Additional options to pass to Google e.g. &xx=yy..."
  :type '(choice
          (const :tag "None" nil)
          (string :tag "Options"))
  :group 'emacspeak-websearch)

(defadvice gweb-google-autocomplete (after emacspeak pre act comp)
  "Cache the query."
  (declare (special emacspeak-google-query))
  (setq emacspeak-google-query ad-return-value))

;;;###autoload
(defun emacspeak-websearch-google (query &optional lucky)
  "Perform a Google search.
Optional interactive prefix arg `lucky' is equivalent to hitting the
I'm Feeling Lucky button on Google.
Uses  customizable option `emacspeak-websearch-google-results-only' to determine if we show just results."
  (interactive
   (list
    (gweb-google-autocomplete)
    current-prefix-arg))
  (declare (special emacspeak-google-query emacspeak-google-toolbelt
                    emacspeak-websearch-google-results-only
                    emacspeak-websearch-google-options
                    emacspeak-websearch-google-number-of-results))
  (let ((toolbelt (emacspeak-google-toolbelt)))
    (emacspeak-webutils-cache-google-query query)
    (emacspeak-webutils-cache-google-toolbelt toolbelt)
    (if lucky
        (emacspeak-webutils-autospeak)
      (emacspeak-webutils-post-process "Results" 'emacspeak-speak-line))
    (let ((emacspeak-w3-tidy-html t)
          (search-url
           (concat
            (emacspeak-websearch-google-uri)
            query
            (format "&num=%s%s"         ; acumulate options
                    emacspeak-websearch-google-number-of-results
                    (or emacspeak-websearch-google-options ""))
            (when lucky
              (concat
               "&btnI="
               (emacspeak-url-encode "I'm Feeling Lucky"))))))
      (cond
       (lucky (browse-url search-url))
       (emacspeak-websearch-google-results-only
        (emacspeak-we-extract-by-id-list
         (list "subform_ctrl" "res" "nav")
         search-url 'speak))
       (t (emacspeak-webutils-with-xsl-environment
           (expand-file-name "default.xsl" emacspeak-xslt-directory)
           nil emacspeak-xslt-options
           (browse-url search-url)))))))
;;{{{ IMFA

(emacspeak-websearch-set-searcher 'agoogle
                                  'emacspeak-websearch-accessible-google)

(emacspeak-websearch-set-key ?a 'agoogle)
;;}}}

(defvar emacspeak-websearch-accessible-google-url
  "http://www.google.com/cse?cx=000183394137052953072%3Azc1orsc6mbq&nojs=1&ie=UTF-8&sa=Search&q="
  "Google Accessible Search -- see http://labs.google.com/accessible")

;;;###autoload
(defun emacspeak-websearch-accessible-google(query)
  "Google Accessible Search -- see http://labs.google.com/accessible"
  (interactive
   (list
    (gweb-google-autocomplete "AGoogle: ")))
  (declare (special emacspeak-websearch-accessible-google-url))
  (let ((emacspeak-w3-tidy-html nil))
    (emacspeak-webutils-cache-google-query query)
    (emacspeak-webutils-post-process "results" 'emacspeak-speak-line)
    (emacspeak-webutils-with-xsl-environment
     (expand-file-name "default.xsl" emacspeak-xslt-directory)
     nil emacspeak-xslt-options
     (browse-url
      (concat emacspeak-websearch-accessible-google-url query)))))

(emacspeak-websearch-set-searcher 'google-lucky
                                  'emacspeak-websearch-google-feeling-lucky)

(emacspeak-websearch-set-key ?\  'google-lucky)

;;;###autoload
(defun emacspeak-websearch-google-feeling-lucky (query)
  "Do a I'm Feeling Lucky Google search."
  (interactive
   (list
    (gweb-google-autocomplete "Google Lucky Search: ")))
  (emacspeak-websearch-google query 'lucky))

(emacspeak-websearch-set-searcher 'google-specialize
                                  'emacspeak-websearch-google-specialize)

(emacspeak-websearch-set-key ?, 'google-specialize)

;;;###autoload
(defun emacspeak-websearch-google-specialize (specialize query)
  "Perform a specialized Google search. See the Google site for
  what is possible here:
https://www.google.com/options/specialsearches.html "
  (interactive
   (list
    (emacspeak-websearch-read-query
     "Specialize google Search On: ")
    (emacspeak-websearch-read-query
     "Google for:")))
  (let ((emacspeak-websearch-google-uri-template
         (format "www.google.com/%s?q="
                 specialize)))
    (emacspeak-websearch-google query )))

;;;###autoload
(defun emacspeak-websearch-google-search-in-date-range ()
  "Use this from inside the calendar to do Google date-range searches."
  (interactive)
  (declare (special calendar-mark-ring))
  (let ((query (emacspeak-websearch-read-query "Google for: "))
        (from (read (calendar-astro-date-string (calendar-cursor-to-date t))))
        (to (read (calendar-astro-date-string (or (car calendar-mark-ring)
                                                  (error "No mark set in this buffer"))))))
    (emacspeak-websearch-google
     (concat
      (emacspeak-url-encode query )
      (format "+daterange:%s-%s"
              (min from to)
              (max from to))))))

(when (featurep 'calendar)
  (declaim (special calendar-mode-map))
  (define-key calendar-mode-map "gg"
    'emacspeak-websearch-google-search-in-date-range))

;;}}}
;;{{{ Google Swiss Army Knife:
(emacspeak-websearch-set-searcher 'google-sak
                                  'emacspeak-websearch-google-sak)

(emacspeak-websearch-set-key ?\' 'google-sak )
(defvar emacspeak-websearch-google-images
  "http://images.google.com/images?hl=en&ie=UTF-8&q="
  "URI for Google Image Search.")

(defvar emacspeak-websearch-google-news-uri
  "http://groups.google.com/grphp?hl=en&ie=UTF-8&q="
  "URI for Google News search.")

(defvar emacspeak-websearch-froogle-uri
  "http://froogle.google.com/frghp?hl=en&ie=UTF-8&q="
  "URI for Google Froogle.")
(defvar emacspeak-websearch-google-html-maps-uri
  "http://maps.google.com/?output=html&hl=en&ie=UTF-8&f=q&q="
  "URI for Google Maps using plain HTML.")

(defvar emacspeak-websearch-google-scholar-uri
  "http://scholar.google.com/scholar?ie=UTF-8&oe=UTF-8&hl=en&num=25&q="
  "URI for Google Scholar search.")

(defvar emacspeak-websearch-google-books-uri
  "http://books.google.com/books?btnG=Search+Books&hl=en&q="
  "URI for Google Book Search.")

(defvar emacspeak-websearch-google-videos-uri
  "http://video.google.com/videofeed?type=search&q="
  "URI for Google Video search.")

(defvar emacspeak-websearch-google-launch-uris
  (list
   (cons 'web (emacspeak-websearch-google-uri))
   (cons 'images  emacspeak-websearch-google-images)
   (cons 'news emacspeak-websearch-google-news-uri)
   (cons 'froogle emacspeak-websearch-froogle-uri)
   (cons 'books emacspeak-websearch-google-books-uri)
   (cons 'scholar emacspeak-websearch-google-scholar-uri)
   (cons 'maps emacspeak-websearch-google-html-maps-uri)
   (cons 'videos emacspeak-websearch-google-videos-uri))
  "Association list of Google search URIs.")

;;;###autoload
(defun emacspeak-websearch-google-sak(engine query)
  "Perform a Google query against a specific index."
  (interactive
   (list
    (completing-read "Engine: "
                     emacspeak-websearch-google-launch-uris)
    (gweb-google-autocomplete "Google for: ")))
  (declare (special emacspeak-websearch-read-query))
  (browse-url
   (concat (cdr (assq engine
                      emacspeak-websearch-google-launch-uris))
           (emacspeak-url-encode query))))

;;}}}
;;{{{ google advanced search

(emacspeak-websearch-set-searcher 'google-advanced
                                  'emacspeak-websearch-google-advanced)

(emacspeak-websearch-set-key ?. 'google-advanced)

(defvar emacspeak-websearch-google-advanced-form
  (expand-file-name "xml-forms/google-advanced.xml"
                    emacspeak-lisp-directory)
  "Markup for Google advanced search form.")

;;;###autoload
(defun emacspeak-websearch-google-advanced ()
  "Present Google advanced search form simplified for speech interaction."
  (interactive)
  (declare (special emacspeak-websearch-google-advanced-form))
  (emacspeak-websearch-display-form emacspeak-websearch-google-advanced-form))

;;}}}
;;{{{ google mobile
(emacspeak-websearch-set-searcher 'google-mobile
                                  'emacspeak-websearch-google-mobile)

(emacspeak-websearch-set-key ?\; 'google-mobile)

(defvar emacspeak-websearch-google-mobile-uri
  "https://www.google.com/xhtml?q="
  "Google mobile search.")

;;;###autoload
(defun emacspeak-websearch-google-mobile (query)
  "Google mobile search."
  (interactive
   (list
    (gweb-google-autocomplete "Google Mobile: ")))
  (declare (special emacspeak-websearch-google-mobile-uri))
  (browse-url
   (concat emacspeak-websearch-google-mobile-uri
           (emacspeak-url-encode query)))
  (emacspeak-webutils-post-process
   query
   'emacspeak-speak-rest-of-buffer))

;;}}}
;;{{{ Google News

(emacspeak-websearch-set-searcher 'google-news
                                  'emacspeak-websearch-google-news)

(emacspeak-websearch-set-key ?n 'google-news )

;;;###autoload
(defun emacspeak-websearch-google-news ()
  "Invoke Google News url template."
  (interactive)
  (let ((name "Google News Search"))
    (emacspeak-url-template-open
     (emacspeak-url-template-get name))))

;;}}}
;;{{{  advanced usenet search

(emacspeak-websearch-set-searcher 'google-usenet-advanced
                                  'emacspeak-websearch-google-usenet-advanced)

(emacspeak-websearch-set-key ?u 'google-usenet-advanced)

(defvar emacspeak-websearch-google-usenet-advanced-form
  (expand-file-name "xml-forms/google-usenet-advanced.xml"
                    emacspeak-lisp-directory)
  "Usenet advanced search from google.")

;;;###autoload
(defun emacspeak-websearch-google-usenet-advanced ()
  "Present Google Usenet advanced search form simplified for speech interaction."
  (interactive)
  (declare (special emacspeak-websearch-google-usenet-advanced-form))
  (emacspeak-websearch-display-form emacspeak-websearch-google-usenet-advanced-form))

;;}}}
;;{{{  Ask Jeeves

(emacspeak-websearch-set-searcher 'jeeves
                                  'emacspeak-websearch-ask-jeeves)
(emacspeak-websearch-set-key ?j 'jeeves)

(defvar emacspeak-websearch-jeeves-uri
  "http://www.ask.com/web?qsrc=0&o=0&ASKDSBHO=0&q="
  "URI for Ask Jeeves  search")

;;;###autoload
(defun emacspeak-websearch-ask-jeeves (query)
  "Ask Jeeves for the answer."
  (interactive
   (list (emacspeak-websearch-read-query "Ask Jeeves for: ")))
  (declare (special emacspeak-websearch-jeeves-uri))
  (browse-url
   (concat emacspeak-websearch-jeeves-uri
           (emacspeak-url-encode query)))
  (emacspeak-webutils-post-process query 'emacspeak-speak-line))

;;}}}
;;{{{ Driving directions from Yahoo

(emacspeak-websearch-set-searcher 'map-yahoo-directions
                                  'emacspeak-websearch-map-yahoo-directions-search)
(emacspeak-websearch-set-key ?m 'map-yahoo-directions)

(defvar emacspeak-websearch-map-yahoo-directions-uri
  "http://maps.yahoo.com/py/ddResults.py?Pyt=Tmap&doit=1&newname=&newdesc=&Get+Directions=Get+Directions&textonly=1"
  "URI for getting driving directions from Yahoo.")

(defvar emacspeak-websearch-map-yahoomaps-uri
  "http://maps.yahoo.com/py/maps.py?Pyt=Tmap&Get%A0Map=Get+Map&"
  "URI for obtaining location maps.")

(defsubst emacspeak-websearch-map-yahoomaps-get-location ()
  "Convenience function for prompting and constructing the route component."
  (concat
   (format "&addr=%s"
           (emacspeak-url-encode
            (read-from-minibuffer "Street Address: ")))
   (format "&csz=%s"
           (emacspeak-url-encode
            (read-from-minibuffer "City/State or Zip:")))))

(defsubst emacspeak-websearch-map-yahoo-directions-get-locations ()
  "Convenience function for prompting and constructing the route component."
  (concat
   (format "&newaddr=%s"
           (emacspeak-url-encode
            (read-from-minibuffer "Start Address: ")))
   (format "&newcsz=%s"
           (emacspeak-url-encode
            (read-from-minibuffer "City/State or Zip:")))
   (format "&newtaddr=%s"
           (emacspeak-url-encode
            (read-from-minibuffer "Destination Address: ")))
   (format "&newtcsz=%s"
           (emacspeak-url-encode
            (read-from-minibuffer "City/State or Zip:")))))

;;;###autoload
(defun emacspeak-websearch-map-yahoo-directions-search (query
                                                        &optional map)
  "Get driving directions from Yahoo.
With optional interactive prefix arg MAP shows the location map instead."
  (interactive
   (list
    (if current-prefix-arg
        (emacspeak-websearch-map-yahoomaps-get-location)
      (emacspeak-websearch-map-yahoo-directions-get-locations))
    current-prefix-arg))
  (declare (special emacspeak-websearch-map-yahoo-directions-uri
                    emacspeak-xslt-use-wget-to-download
                    emacspeak-websearch-map-yahoomaps-uri))
  (let ((emacspeak-xslt-use-wget-to-download t))
    (cond
     (map
      (browse-url
       (concat
        emacspeak-websearch-map-yahoomaps-uri
        query))
      (emacspeak-webutils-post-process
       "Nearby"
       'emacspeak-speak-line))
     (t
      (emacspeak-we-extract-table-by-match "Start"
                                           (concat
                                            emacspeak-websearch-map-yahoo-directions-uri
                                            query)
                                           'speak)))))

;;}}}
;;{{{  news yahoo

(emacspeak-websearch-set-searcher 'news-yahoo
                                  'emacspeak-websearch-news-yahoo)
(emacspeak-websearch-set-key ?N 'news-yahoo)

(defvar emacspeak-websearch-news-yahoo-uri
  "http://search.news.yahoo.com/search/news?"
  "*URI for launching a Yahoo News search")

(defvar emacspeak-websearch-news-yahoo-rss-uri
  "http://news.search.yahoo.com/news/rss?"
  "*RSS URI for launching a Yahoo News search")

;;;###autoload
(defun emacspeak-websearch-news-yahoo (query &optional no-rss)
  "Perform an Yahoo News search.
Optional prefix arg no-rss scrapes information from HTML."
  (interactive
   (list
    (emacspeak-websearch-read-query "Yahoo News Query: ")
    current-prefix-arg))
  (add-hook 'emacspeak-web-post-process-hook
            #'(lambda nil
                (declare (special  emacspeak-we-url-rewrite-rule
                                   emacspeak-websearch-news-yahoo-rss-uri
                                   emacspeak-we-class-filter))
                (setq emacspeak-we-class-filter "article"
                      emacspeak-we-url-rewrite-rule
                      '("$" "&printer=1"))))
  (cond
   ((null no-rss)                       ;use rss feed
    (emacspeak-webutils-rss-display
     (concat emacspeak-websearch-news-yahoo-rss-uri
             (format "p=%s&n=20&c=news"
                     (emacspeak-url-encode query)))))
   (t
    (emacspeak-we-xslt-filter
     "//ol"
     (concat emacspeak-websearch-news-yahoo-uri
             (format "p=%s&n=20&c=news"
                     (emacspeak-url-encode query)))
     'speak-result))))

;;}}}
;;{{{  Open Directory

(emacspeak-websearch-set-searcher 'open-directory
                                  'emacspeak-websearch-open-directory-search)
(emacspeak-websearch-set-key ?o 'open-directory)

(defvar emacspeak-websearch-open-directory-uri
  "http://search.dmoz.org/cgi-bin/search?search="
  "*URI for launching a Open Directory search")

;;;###autoload
(defun emacspeak-websearch-open-directory-search (query)
  "Perform an Open Directory search"
  (interactive
   (list
    (emacspeak-websearch-read-query
     "Search Open Directory for: ")))
  (declare (special emacspeak-websearch-open-directory-uri))
  (browse-url
   (concat emacspeak-websearch-open-directory-uri
           (emacspeak-url-encode query)))
  (emacspeak-webutils-post-process
   "Search results"
   'emacspeak-speak-line))

;;}}}
;;{{{ RPMFind

(emacspeak-websearch-set-searcher 'rpm-find
                                  'emacspeak-websearch-rpm-find)

(emacspeak-websearch-set-key 18 'rpm-find)

(defvar emacspeak-websearch-rpm-find-uri
  "http://rpmfind.net/linux/rpm2html/search.php?query="
  "*URI for RPM  Site search")

;;;###autoload
(defun emacspeak-websearch-rpm-find (query)
  "Search RPM  catalog  site."
  (interactive
   (list
    (emacspeak-websearch-read-query "Find RPM: ")))
  (declare (special emacspeak-websearch-rpm-find-uri))
  (browse-url
   (concat emacspeak-websearch-rpm-find-uri
           (emacspeak-url-encode query)))
  (emacspeak-webutils-post-process
   query
   'emacspeak-speak-line))

;;}}}
;;{{{  Recorded books

(emacspeak-websearch-set-searcher 'recorded-books
                                  'emacspeak-websearch-recorded-books-search)

                                        ;(emacspeak-websearch-set-key ?r 'recorded-books)

(defvar emacspeak-websearch-recorded-books-advanced-form
  (expand-file-name "xml-forms/recorded-books-advanced.xml"
                    emacspeak-lisp-directory)
  "Search form for finding recorded books.")

;;;###autoload
(defun emacspeak-websearch-recorded-books-search ()
  "Present advanced search form for recorded books."
  (interactive)
  (declare (special emacspeak-websearch-recorded-books-advanced-form))
  (emacspeak-websearch-display-form emacspeak-websearch-recorded-books-advanced-form))

;;}}}
;;{{{ Merriam Webster

(emacspeak-websearch-set-searcher 'merriam-webster
                                  'emacspeak-websearch-merriam-webster-search)
(emacspeak-websearch-set-key ?d 'merriam-webster)

(defvar emacspeak-websearch-merriam-webster-uri
  "http://www.m-w.com/cgi-bin/dictionary?va="
  "URI for searching the Merriam Webster dictionary.")

;;;###autoload
(defun emacspeak-websearch-merriam-webster-search (query)
  "Search the Merriam Webster Dictionary."
  (interactive
   (list
    (emacspeak-websearch-read-query "Lookup word in Webster:")))
  (declare (special emacspeak-websearch-merriam-webster-uri))
  (browse-url
   (concat emacspeak-websearch-merriam-webster-uri
           (emacspeak-url-encode query)))
  (emacspeak-webutils-post-process
   "Main Entry"
   'emacspeak-speak-line))

;;}}}
;;{{{ Weather

(emacspeak-websearch-set-searcher 'weather
                                  'emacspeak-websearch-weather)
(emacspeak-websearch-set-key ?w 'weather)

(defvar emacspeak-websearch-weather-uri
  "http://www.srh.noaa.gov/zipcity.php?inputstring="
  "*URI for getting weather forecast.")

;;;###autoload
(defun emacspeak-websearch-weather (query)
  "Get weather forecast for specified zip code."
  (interactive
   (list (emacspeak-websearch-read-query "City,State or Zip: ")))
  (declare (special emacspeak-websearch-weather-uri))
  (emacspeak-we-extract-tables-by-match-list
   (list "Area" "Humidity" )
   (concat emacspeak-websearch-weather-uri
           (emacspeak-url-encode query))
   'speak))

;;}}}
;;{{{ W3C

(emacspeak-websearch-set-searcher 'w3c
                                  'emacspeak-websearch-w3c-search)
(emacspeak-websearch-set-key ?W 'w3c)

(defvar emacspeak-websearch-w3c-search-uri
  "http://search.w3.org/Member/cgi-bin/query?mss=simple&pg=q&what=web&filter=all&fmt=."
  "URI for searching the member area of the W3C site.")

;;;###autoload
(defun emacspeak-websearch-w3c-search (query)
  "Search the W3C Site."
  (interactive
   (list (emacspeak-websearch-read-query "Search W3C site: ")))
  (declare (special emacspeak-websearch-w3c-search-uri))
  (browse-url
   (concat emacspeak-websearch-w3c-search-uri
           "&q="
           (emacspeak-url-encode query)))
  (emacspeak-webutils-post-process
   "match"
   'emacspeak-speak-line))

;;}}}
;;{{{ wikipedia

(emacspeak-websearch-set-searcher 'wikipedia
                                  'emacspeak-websearch-wikipedia-search)

(emacspeak-websearch-set-key 23 'wikipedia)

;;;###autoload
(defun emacspeak-websearch-wikipedia-search (query)
  "Search Wikipedia using Google."
  (interactive
   (list (emacspeak-websearch-read-query "Search Wikipedia: ")))
  
  
  (emacspeak-websearch-google
   (emacspeak-url-encode (format "site:wikipedia.org %s"query))))

;;}}}
;;{{{ yahoo

(emacspeak-websearch-set-searcher 'yahoo
                                  'emacspeak-websearch-yahoo)
(emacspeak-websearch-set-key ?y 'yahoo)

(defvar emacspeak-websearch-yahoo-uri
  "http://search.yahoo.com/bin/search?p="
  "*URI for launching a Yahoo  search")

;;;###autoload
(defun emacspeak-websearch-yahoo (query)
  "Perform an Yahoo  search"
  (interactive
   (list (emacspeak-websearch-read-query "Yahoo Query: ")))
  (declare (special emacspeak-websearch-yahoo-uri))
  (browse-url
   (concat emacspeak-websearch-yahoo-uri
           (emacspeak-url-encode query)))
  (emacspeak-webutils-post-process
   "
Results"
   'emacspeak-speak-line))

;;}}}
;;{{{ Exchange rate convertor

(emacspeak-websearch-set-searcher 'exchange-rate-convertor
                                  'emacspeak-websearch-exchange-rate-convertor)

(emacspeak-websearch-set-key ?X 'exchange-rate-convertor)

(defvar emacspeak-websearch-exchange-rate-form
  (expand-file-name "xml-forms/exchange-rate-convertor.xml"
                    emacspeak-lisp-directory)
  "Form for performing currency conversion.")

(defvar emacspeak-websearch-exchange-rate-convertor-uri
  "http://www.xe.com/ucc/convert.cgi?Amount=1&From=%s&To=%s&submit=Perform+Conversion"
  "URI template  for currency conversion.")

;;;###autoload
(defun emacspeak-websearch-exchange-rate-convertor (conversion-spec)
  "Currency convertor."
  (interactive
   (list
    (read-from-minibuffer
     "Currency Convertor: FROM|TO:")))
  (declare (special emacspeak-websearch-exchange-rate-convertor-uri))
  (let ((fields (split-string conversion-spec "|"))
        (url nil))
    (setq url
          (format emacspeak-websearch-exchange-rate-convertor-uri
                  (upcase (first fields))
                  (upcase (second fields))))
    (emacspeak-we-extract-table-by-match
     "↔"
     url 'speak)))

;;}}}
;;{{{ Yahoo Exchange rate convertor

(emacspeak-websearch-set-searcher 'y-exchange-rate-convertor
                                  'emacspeak-websearch-yahoo-exchange-rate-convertor)

(emacspeak-websearch-set-key ?x 'y-exchange-rate-convertor)

(defvar emacspeak-websearch-yahoo-exchange-rate-convertor-uri
  "http://download.finance.yahoo.com/d/quotes.csv?s=%s=X&f=sl1d1t1ba&e=.csv"
  "URI template  for currency conversion.")

;;;###autoload
(defun emacspeak-websearch-yahoo-exchange-rate-convertor (conversion-spec)
  "Currency convertor."
  (interactive
   (list
    (read-from-minibuffer
     "Currency Convertor: FromTo:")))
  (declare (special emacspeak-websearch-yahoo-exchange-rate-convertor-uri))
  (let* ((url 
          (format emacspeak-websearch-yahoo-exchange-rate-convertor-uri
                  (upcase  conversion-spec)))
         (buffer (url-retrieve-synchronously url)))
    (save-excursion
      (set-buffer buffer)
      (goto-char (point-min))
      (search-forward "\n\n")
      (delete-region (point-min) (point))
      (emacspeak-table-view-csv-buffer buffer)
      (kill-buffer buffer)
      (when (get-buffer "Currency Rates")
        (kill-buffer "Currency Rates"))
      (rename-buffer "Currency Rates"))))

;;}}}
;;{{{ Shopping at Amazon

(emacspeak-websearch-set-searcher 'amazon-search
                                  'emacspeak-websearch-amazon-search)

(emacspeak-websearch-set-key 1 'amazon-search)

(defvar emacspeak-websearch-amazon-search-form
  "http://www.amazon.com/access"
  "Form for Amazon store search.")

;;;###autoload
(defun emacspeak-websearch-amazon-search ()
  "Amazon search."
  (interactive)
  (declare (special emacspeak-websearch-amazon-search-form))
  (browse-url emacspeak-websearch-amazon-search-form))

;;}}}
;;{{{ Shopping at ebay

(emacspeak-websearch-set-searcher 'ebay-search
                                  'emacspeak-websearch-ebay-search)

(emacspeak-websearch-set-key 5 'ebay-search)

(defvar emacspeak-websearch-ebay-search-form
  (expand-file-name "xml-forms/ebay-search.xml"
                    emacspeak-lisp-directory)
  "Form for Ebay store search.")

;;;###autoload
(defun emacspeak-websearch-ebay-search ()
  "Ebay search."
  (interactive)
  (declare (special emacspeak-websearch-ebay-search-form))
  (emacspeak-websearch-display-form emacspeak-websearch-ebay-search-form))

;;}}}
;;{{{  site-specific search tools

;;; Load site-specific searchers

(when (locate-library "emacspeak-w3search")
  (load-library "emacspeak-w3search"))

;;}}}
;;{{{ Browse usenet

(defvar emacspeak-usenet-feeds-uri
  "http://groups.google.com/group/%s/feed/rss_v2_0_msgs.xml"
  "RSS Feed from Google for Usenet groups.")

(defvar emacspeak-usenet-uri
  "http://groups.google.com/group/"
  "URI to open a group on Usenet archive.")
;;;###autoload
(defun emacspeak-websearch-usenet (group &optional prefix)
  "Prompt and browse a Usenet newsgroup.
Optional interactive prefix arg results in prompting for a search term."
  (interactive
   (list
    (read-from-minibuffer "Newsgroup: ")
    current-prefix-arg))
  (declare (special emacspeak-usenet-uri
                    emacspeak-usenet-feeds-uri))
  (let ((url nil))
    (cond
     (prefix                            ;search
      (setq url
            (format
             "%s%s/search?group=%s&q=%s&qt_g=1&searchnow=Search+this+group&num=%s&scoring=d"
             emacspeak-usenet-uri
             group group
             (emacspeak-url-encode
              (read-from-minibuffer
               (format "Search %s for:" group)))
             emacspeak-websearch-google-number-of-results))
      (emacspeak-webutils-without-xsl
       (browse-url  url)
       (emacspeak-webutils-post-process
        "Sort by"
        'emacspeak-speak-line)))
     (t                                 ;browse
      (setq url
            (format emacspeak-usenet-feeds-uri group))
      (emacspeak-webutils-rss-display url)))))

;;}}}

;;}}}
(provide 'emacspeak-websearch)
;;{{{ end of file

;;; local variables:
;;; folded-file: t
;;; byte-compile-dynamic: nil
;;; end:

;;}}}
