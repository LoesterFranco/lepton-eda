#!/usr/bin/env sh
export GUILE_LOAD_COMPILED_PATH="@ccachedir@:${GUILE_LOAD_COMPILED_PATH}"
exec @GUILE@ -s "$0" "$@"
!#

;;; Lepton EDA attribute editor
;;; Copyright (C) 1998-2016 gEDA Contributors
;;; Copyright (C) 2017-2020 Lepton EDA Contributors
;;;
;;; This program is free software; you can redistribute it and/or modify
;;; it under the terms of the GNU General Public License as published by
;;; the Free Software Foundation; either version 2 of the License, or
;;; (at your option) any later version.
;;;
;;; This program is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with this program; if not, write to the Free Software
;;; Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA


(use-modules (ice-9 match)
             (srfi srfi-37)
             (system foreign))

;;; Load and initialize liblepton library.
(load-extension (or (getenv "LIBLEPTON") "@libdir@/liblepton")
                "liblepton_init")

(primitive-eval '(use-modules (lepton color-map)
                              (lepton eval)
                              (lepton log)
                              (lepton version)
                              (schematic core gettext)))


(define libgtk (dynamic-link "libgtk-x11-2.0"))
(define libleptongui (dynamic-link "libleptongui"))

(define gtk-init
  (pointer->procedure
   void
   (dynamic-func "gtk_init" libgtk)
   (list '* '*)))

(define gtk-main
  (pointer->procedure
   void
   (dynamic-func "gtk_main" libgtk)
   '()))


(define register-funcs
  (pointer->procedure
   void
   (dynamic-func "g_register_funcs" libleptongui)
   '()))

(define init-window
  (pointer->procedure
   void
   (dynamic-func "g_init_window" libleptongui)
   '()))

(define init-select
  (pointer->procedure
   void
   (dynamic-func "g_init_select" libleptongui)
   '()))

(define init-hook
  (pointer->procedure
   void
   (dynamic-func "g_init_hook" libleptongui)
   '()))

(define init-action
  (pointer->procedure
   void
   (dynamic-func "g_init_action" libleptongui)
   '()))

(define init-attrib
  (pointer->procedure
   void
   (dynamic-func "g_init_attrib" libleptongui)
   '()))

(define init-keys
  (pointer->procedure
   void
   (dynamic-func "g_init_keys" libleptongui)
   '()))

(define init-builtins
  (pointer->procedure
   void
   (dynamic-func "g_init_builtins" libleptongui)
   '()))

(define init-util
  (pointer->procedure
   void
   (dynamic-func "g_init_util" libleptongui)
   '()))

(define init-undo
  (pointer->procedure
   void
   (dynamic-func "scheme_init_undo" libleptongui)
   '()))

(define init-buffers
  (pointer->procedure
   void
   (dynamic-func "o_buffer_init" libleptongui)
   '()))

(define init-color
  (pointer->procedure
   void
   (dynamic-func "x_color_init" libleptongui)
   '()))

(define init-undo*
  (pointer->procedure
   void
   (dynamic-func "o_undo_init" libleptongui)
   '()))

(define set-quiet-mode!
  (pointer->procedure
   void
   (dynamic-func "set_quiet_mode" libleptongui)
   '()))

(define set-verbose-mode!
  (pointer->procedure
   void
   (dynamic-func "set_verbose_mode" libleptongui)
   '()))


;;; Localization.
(bindtextdomain %schematic-gettext-domain "@localedir@")
(textdomain %schematic-gettext-domain)
(bind-textdomain-codeset %schematic-gettext-domain "UTF-8")
(setlocale LC_ALL "")
(setlocale LC_NUMERIC "C")


;;; Precompilation.
(define (precompile-mode)
  (getenv "LEPTON_SCM_PRECOMPILE"))

(define (precompile-prepare)
  (setenv "GUILE_AUTO_COMPILE" "0"))

;;; Add Lepton compiled path to Guile compiled paths env var.
(define (set-guile-compiled-path)
  (set! %load-compiled-path (cons "@ccachedir@"
                                  %load-compiled-path)))
(define (register-guile-funcs)
  (register-funcs)
  (init-window)
  (init-select)
  (init-hook)
  (init-action)
  (init-attrib)
  (init-keys)
  (init-builtins)
  (init-util)
  (init-undo))

(define (precompile-run)
  (let ((script (getenv "LEPTON_SCM_PRECOMPILE_SCRIPT")))
    (if script
        (begin (register-guile-funcs)
               ;; Actually load the script.
               (primitive-load script)
               0)
        1)))


(define add-post-load-expr! #f)
(define eval-post-load-expr! #f)

;;; Contains a Scheme expression arising from command-line
;;; arguments.  This is evaluated after loading lepton-schematic
;;; and any schematic files specified on the command-line.
(let ((post-load-expr '()))
  (set! add-post-load-expr!
        (lambda (expr script?)
          (set! post-load-expr
                (cons (list (if script? 'load 'eval-string) expr)
                      post-load-expr))))
  (set! eval-post-load-expr!
        (lambda ()
          (eval-protected
           (cons 'begin (reverse post-load-expr))))))


;;; Print brief help message describing lepton-schematic usage and
;;; command-line options, and exit with exit status 0.
(define (usage)
  (format #t
          (G_ "Usage: ~A [OPTION ...] [--] [FILE ...]


Interactively edit Lepton EDA schematics or symbols.
If one or more FILEs are specified, open them for
editing; otherwise, create a new, empty schematic.

Options:
  -q, --quiet              Quiet mode.
  -v, --verbose            Verbose mode.
  -L DIR                   Add DIR to Scheme search path.
  -c EXPR                  Scheme expression to run at startup.
  -s FILE                  Scheme script to run at startup.
  -V, --version            Show version information.
  -h, --help               Help; this message.
  --                       Treat all remaining arguments as filenames.

Report bugs at ~S
Lepton EDA homepage: ~S\n")
          (car (program-arguments))
          (lepton-version-ref 'bugs)
          (lepton-version-ref 'url))
  (primitive-exit 0))


;;; Parse lepton-schematic command-line options, displaying usage
;;; message or version information as required.
(define (parse-commandline)
  "Parse command line options"
  (reverse
   (args-fold
    (cdr (program-arguments))
    (list
     (option '(#\q "quiet") #f #f
             (lambda (opt name arg seeds)
               (set-quiet-mode!)
               seeds))
     (option '(#\v "verbose") #f #f
             (lambda (opt name arg seeds)
               (set-verbose-mode!)
               seeds))
     (option '(#\L) #t #f
             (lambda (opt name arg seeds)
               (add-to-load-path arg)
               seeds))
     (option '(#\s) #t #f
             (lambda (opt name arg seeds)
               (add-post-load-expr! arg #t)
               seeds))
     (option '(#\c) #t #f
             (lambda (opt name arg seeds)
               (add-post-load-expr! arg #f)
               seeds))
     (option '(#\h #\? "help") #f #f
             (lambda (opt name arg seeds)
               (usage)))
     (option '(#\V "version") #f #f
             (lambda (opt name arg seeds)
               (display-lepton-version #:print-name #t #:copyright #t)
               (primitive-exit 0))))
    (lambda (opt name arg seeds)
      (format #t
              (G_ "ERROR: Unknown option ~A.
Run `~A --help' for more information.\n")
              (if (char? name)
                  (string-append "-" (char-set->string (char-set name)))
                  (string-append "--" name))
              (basename (car (program-arguments))))
      (primitive-exit 1))
    (lambda (op seeds) (cons op seeds))
    '())))


(define main
  (pointer->procedure
   void
   (dynamic-func "main_prog" libleptongui)
   (list '*)))

;;; Init logging.
(init-log "schematic")
(display-lepton-version #:print-name #t #:log #t)

;;; Precompilation.
(if (precompile-mode)
    (precompile-prepare)
    (set-guile-compiled-path))

;;; Run precompilation.
(when (precompile-mode)
  (primitive-exit (precompile-run)))

;;; Initialize GTK.
(gtk-init %null-pointer %null-pointer)

;;; Init global buffers.
(init-buffers)

;;; Register guile (scheme) functions
(register-guile-funcs)

;;; Initialise color map (need to do this before reading rc
;;; files).
(init-color)
(init-undo*)

(let ((schematics (parse-commandline)))
  (main (scm->pointer schematics)))

(eval-post-load-expr!)

;;; Run main GTK loop.
(gtk-main)
