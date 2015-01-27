(require 'package)
(package-initialize)
(require 'autopair)
(require 'multiple-cursors)
(require 'undo-tree)
(require 'yasnippet)
(require 'rainbow-delimiters)
(require 'key-chord)
(require 'browse-kill-ring)
(require 'emmet-mode)
(require 'ido)
(require 'go-mode)

(require 'auto-complete)
(require 'auto-complete-config)
(ac-config-default)

(require 'yasnippet)
(yas-global-mode 1)

;; (require 'web-mode)
(setq inhibit-startup-message t)

(setq ido-enable-flex-matching t)
(setq ido-everywhere t)
(ido-mode t) 
(add-to-list 'package-archives
'("melpa" . "http://melpa.milkbox.net/packages/")t)
(add-to-list 'package-archives 
    '("marmalade" .
      "http://marmalade-repo.org/packages/"))

  ;; The following lines are always needed.  Choose your own keys.
(add-to-list 'auto-mode-alist '("\\.org\\'" . org-mode)) ; not needed since Emacs 22.2
(add-hook 'org-mode-hook 'turn-on-font-lock) ; not needed when global-font-lock-mode is on
(global-set-key "\C-cl" 'org-store-link)
(global-set-key "\C-ca" 'org-agenda)
(global-set-key "\C-cb" 'org-iswitchb)


(global-set-key (kbd "C-'") 'ace-jump-char-mode)
(global-set-key (kbd "C-M-m") 'ace-jump-word-mode)
(global-set-key (kbd "C-.") 'mc/mark-next-like-this)
(global-set-key (kbd "C-,") 'mc/mark-previous-like-this)
(global-set-key (kbd "C-;") 'er/expand-region)
(global-set-key (kbd "C-`") 'point-to-register)
(global-set-key (kbd "C-~") 'jump-to-register)
(add-hook 'sgml-mode-hook 'emmet-mode)
(add-hook 'css-mode-hook 'emmet-mode)
(set-frame-font "monofur-14")
(set-face-font 'mode-line "monofur-14")
(autopair-global-mode 1)
;(eval-after-load 'sgml-mode '(define-key ))
(load-theme 'afternoon t)
(key-chord-define-global "hj" 'undo)
(key-chord-define-global "jk" 'ace-jump-char-mode)
(key-chord-define-global "/a" 'point-to-register)
(key-chord-define-global "/s" 'jump-to-register)
(key-chord-define-global "uu" 'undo-tree-visualize)
(key-chord-define-global "xx" 'execute-extended-command)
(key-chord-define-global "yy" 'browse-kill-ring)
(key-chord-define-global ";;" 'emmet-expand-line)
(key-chord-define-global "qw" 'bookmark-set)
(key-chord-define-global "qe" 'bookmark-jump)
(key-chord-define-global "qr" 'list-bookmarks)
(key-chord-define-global "bn" 'compile)
(key-chord-define-global "fj" 'kill-whole-line)
(key-chord-define-global ",." 'spotify-next)
(key-chord-define-global "nm" 'spotify-previous)


(pending-delete-mode t)
(key-chord-mode 1)
(menu-bar-mode -1)
(tool-bar-mode -1)
(scroll-bar-mode -1)
(yas-global-mode 1)


(defvar-local hidden-mode-line-mode nil)

(define-minor-mode hidden-mode-line-mode
  "Minor mode to hide the mode-line in the current buffer."
  :init-value nil
  :global nil
  :variable hidden-mode-line-mode
  :group 'editing-basics
  (if hidden-mode-line-mode
      (setq hide-mode-line mode-line-format
            mode-line-format nil)
    (setq mode-line-format hide-mode-line
          hide-mode-line nil))
  (when (and (called-interactively-p 'interactive)
             hidden-mode-line-mode)
    (run-with-idle-timer
     0 nil 'message
     (concat "Hidden Mode Line Mode enabled.  "
             "Use M-x hidden-mode-line-mode RET to make the mode-line appear."))))

;; Activate hidden-mode-line-mode
(hidden-mode-line-mode 1)
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(ansi-color-faces-vector [default bold shadow italic underline bold bold-italic bold])
 '(ansi-color-names-vector (vector "#eaeaea" "#d54e53" "DarkOliveGreen3" "#e7c547" "DeepSkyBlue1" "#c397d8" "#70c0b1" "#181a26"))
 '(background-color "#042028")
 '(background-mode dark)
 '(cursor-color "#708183")
 '(custom-safe-themes (quote ("2283e0e235d6f00b717ccd7b1f22aa29ce042f0f845936a221012566a810773d" "fc5fcb6f1f1c1bc01305694c59a1a861b008c534cae8d0e48e4d5e81ad718bc6" default)))
 '(fci-rule-color "#14151E")
 '(foreground-color "#708183")
 '(send-mail-function nil)
 '(vc-annotate-background nil)
 '(vc-annotate-color-map (quote ((20 . "#d54e53") (40 . "goldenrod") (60 . "#e7c547") (80 . "DarkOliveGreen3") (100 . "#70c0b1") (120 . "DeepSkyBlue1") (140 . "#c397d8") (160 . "#d54e53") (180 . "goldenrod") (200 . "#e7c547") (220 . "DarkOliveGreen3") (240 . "#70c0b1") (260 . "DeepSkyBlue1") (280 . "#c397d8") (300 . "#d54e53") (320 . "goldenrod") (340 . "#e7c547") (360 . "DarkOliveGreen3"))))
 '(vc-annotate-very-old-color nil))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )



;; Stuff that Ethan added
(setq visible-bell t)
(setq ring-bell-function 'ignore)

(autoload 'flyspell-mode "flyspell" "On-the-fly spelling checker." t)
(autoload 'flyspell-delay-command "flyspell" "Delay on command." t)
(autoload 'tex-mode-flyspell-verify "flyspell" "" t)
(add-hook 'LaTeX-mode-hook 'turn-on-flyspell)
(setq c-default-style "linux"
      c-basic-offset 4)

(setq-default indent-tabs-mode nil)
(setq-default tab-width 4)
(setq indent-line-function 'insert-tab)
(show-paren-mode 1)

(global-set-key (kbd "M-<up>") 'switch-to-next-buffer)
(global-set-key (kbd "M-<down>") 'switch-to-prev-buffer)
