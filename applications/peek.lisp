;;;; Copyright (c) 2011-2015 Henry Harrington <henry.harrington@gmail.com>
;;;; This code is licensed under the MIT license.

(defpackage :mezzano.gui.peek
  (:use :cl)
  (:export #:spawn))

(in-package :mezzano.gui.peek)

(defvar *peek-commands*
  '((#\? "Help" peek-help "Show a help page.")
    (#\T "Thread" peek-thread "Show currently active threads.")
    (#\M "Memory" peek-memory "Show memory information.")
    (#\N "Network" peek-network "Show network information.")
    (#\C "CPU" peek-cpu "Show CPU information.")
    (#\D "Disk" peek-disk "Show disk information.")
    (#\Q "Quit" nil "Quit Peek")))

(defun print-header ()
  (dolist (cmd *peek-commands*)
    (write-string (second cmd))
    (unless (char-equal (char (second cmd) 0) (first cmd))
      (format t "(~S)" (first cmd)))
    (write-char #\Space)))

(defun peek-help ()
  (format t "      Peek help~%")
  (format t "Char~6TCommand~20TInfo~%")
  (dolist (cmd *peek-commands*)
    (format t "~S~6T~A~20T~A~%" (first cmd) (second cmd) (fourth cmd))))

(defun peek-thread ()
  (format t "Thread Name~24TState~%")
  (dolist (thread (mezzano.supervisor:all-threads))
    (format t " ~A~24T~A~%" (mezzano.supervisor:thread-name thread) (mezzano.supervisor:thread-state thread))
    (when (eql (mezzano.supervisor:thread-state thread) :sleeping)
      (format t "  Waiting on ")
      (print-unreadable-object ((mezzano.supervisor:thread-wait-item thread) *standard-output* :type t :identity t))
      (terpri))))

(defun peek-memory ()
  (room))

(defun format-nic (stream card &optional colon-p at-sign-p)
  (declare (ignore colon-p at-sign-p))
  (print-unreadable-object (card stream :type t :identity t)))

(defun peek-network ()
  (format t "Network cards:~%")
  (dolist (card sys.net::*cards*)
    (let ((address (sys.net::ipv4-interface-address card nil)))
      (format t " ~/mezzano.gui.peek::format-nic/~%" card)
      (format t "   Mac: ~/sys.net::format-mac-address/~%" (mezzano.supervisor:nic-mac card))
      (when address
        (format t "   IPv4 address: ~/sys.net::format-tcp4-address/~%" address))
      (multiple-value-bind (rx-bytes rx-packets rx-errors tx-bytes tx-packets tx-errors collisions)
          (mezzano.supervisor:net-statistics card)
        (format t "   ~:D octets, ~:D packets received. ~:D RX errors.~%"
                rx-bytes rx-packets rx-errors)
        (format t "   ~:D octets, ~:D packets transmitted. ~:D TX errors.~%"
                tx-bytes tx-packets tx-errors)
        (format t "   ~:D collisions.~%" collisions))))
  (format t "Routing table:~%")
  (format t " Network~17TGateway~33TNetmask~49TInterface~%")
  (dolist (route sys.net::*routing-table*)
    (write-char #\Space)
    (if (first route)
        (sys.net::format-tcp4-address *standard-output* (first route))
        (write-string ":DEFAULT"))
    (format t "~17T")
    (if (second route)
        (sys.net::format-tcp4-address *standard-output* (second route))
        (write-string "N/A"))
    (format t "~33T~/sys.net::format-tcp4-address/~49T~/mezzano.gui.peek::format-nic/~%" (third route) (fourth route)))
  (format t "Servers:~%")
  (dolist (server sys.net::*server-alist*)
    (format t "~S  TCPv4 ~D~%" (second server) (first server)))
  (format t "TCPv4 connections:~%")
  (format t " Local~8TRemote~40TState~%")
  (dolist (conn sys.net::*tcp-connections*)
    (format t " ~D~8T~/sys.net::format-tcp4-address/:~D~40T~S~%"
            (sys.net::tcp-connection-local-port conn)
            (sys.net::tcp-connection-remote-ip conn) (sys.net::tcp-connection-remote-port conn)
            (sys.net::tcp-connection-state conn)))
  (format t "UDPv4 connections:~%")
  (format t " Local~8TRemote~%")
  (dolist (conn sys.net::*udp-connections*)
    (format t " ~D~8T~/sys.net::format-tcp4-address/:~D~%"
            (sys.net::local-port conn)
            (sys.net::remote-address conn) (sys.net::remote-port conn))))

(defvar *cpuid-1-ecx-features*
  #("SSE3"
    nil
    nil
    "MONITOR"
    "DS-CPL"
    "VMX"
    "SMX"
    "EST"
    "TM2"
    "SSSE3"
    "CNXT-ID"
    nil
    nil
    "CMPXCHG16B"
    "xTPR"
    "PDCM"
    nil
    nil
    "DCA"
    "SSE4.1"
    "SSE4.2"
    nil
    nil
    "POPCNT"))

(defvar *cpuid-1-edx-features*
  #("FPU"
    "VME"
    "DE"
    "PSE"
    "TSC"
    "MSR"
    "PAE"
    "MCE"
    "CX8"
    "APIC"
    nil
    "SEP"
    "MTRR"
    "PGE"
    "MCA"
    "CMOV"
    "PAT"
    "PSE-36"
    "PSN"
    "CLFSH"
    nil
    "DS"
    "ACPI"
    "MMX"
    "FXSR"
    "SSE"
    "SSE2"
    "SS"
    "HTT"
    "TM"
    nil
    "PBE"))

(defvar *cpuid-ext-1-ecx-features*
  #("LAHF/SAHF"))

(defvar *cpuid-ext-1-edx-features*
  #(nil ; FPU
    nil ; VME
    nil ; DE
    nil ; PSE
    nil ; TSC
    nil ; MSR
    nil ; PAE
    nil ; MCE
    nil ; CMPXCHG8B
    nil ; APIC
    nil
    "SYSCALL"
    nil ; MTRR
    nil ; PGE
    nil ; MCA
    nil ; CMOV
    nil ; PAT
    nil ; PSE36
    nil
    nil
    "NX"
    nil
    "MmxExt"
    nil ; MMX
    nil ; FXSR
    "FFXSR"
    "Page1GB"
    "RDTSCP"
    nil
    "LM"
    "3DNowExt"
    "3DNow"))

(defun scan-feature-bits (feature-seq bits)
  (let ((features '()))
    (dotimes (i (length feature-seq) features)
      (when (and (elt feature-seq i)
                 (logbitp i bits))
        (push (elt feature-seq i) features)))))

(defun peek-cpu ()
  (let ((features '())
        (extended-cpuid-max nil))
    (multiple-value-bind (cpuid-max vendor-1 vendor-3 vendor-2)
        (sys.int::cpuid 0)
      (format t "Maximum CPUID level: ~X~%" cpuid-max)
      (format t "Vendor: ~A~%" (sys.int::decode-cpuid-vendor vendor-1 vendor-2 vendor-3))
      (setf extended-cpuid-max (sys.int::cpuid #x80000000))
      (if (logbitp 31 extended-cpuid-max)
          (format t "Maximum extended CPUID level: ~X~%" extended-cpuid-max)
          (format t "Extended CPUID not supported.~%"))
      (when (>= cpuid-max 1)
        (multiple-value-bind (a b c d)
            (sys.int::cpuid 1)
          (let* ((stepping-id (ldb (byte 4 0) a))
                 (model (ldb (byte 4 4) a))
                 (family-id (ldb (byte 4 8) a))
                 (processor-type (ldb (byte 2 12) a))
                 (extended-model-id (ldb (byte 4 16) a))
                 (extended-family-id (ldb (byte 8 20) a))
                 (display-family (if (= family-id #xF)
                                     (+ family-id extended-family-id)
                                     family-id))
                 (displayed-model (if (or (= family-id #x6) (= family-id #xF))
                                      (+ (ash extended-model-id 4) model)
                                      model))
                 (brand (ldb (byte 8 0) b)))
            (format t "Model: ~X  Family: ~X  Stepping: ~X  Processor type: ~X  Brand index: ~D~%"
                    displayed-model display-family stepping-id processor-type brand))
          (format t "CLFLUSH size: ~D bytes~%" (* (ldb (byte 8 8) b) 8))
          (format t "Local APIC ID: ~D~%" (ldb (byte 8 24) b))
          (setf features (nconc (scan-feature-bits *cpuid-1-ecx-features* c)
                                (scan-feature-bits *cpuid-1-edx-features* d)
                                features))))
      (when (>= extended-cpuid-max #x80000001)
        (multiple-value-bind (a b c d)
            (sys.int::cpuid #x80000001)
          (setf features (nconc (scan-feature-bits *cpuid-ext-1-ecx-features* c)
                                (scan-feature-bits *cpuid-ext-1-edx-features* d)
                                features)))))
    (format t "Features: ~A~%" features)))

(defun peek-disk ()
  (dolist (disk (mezzano.supervisor:all-disks))
    (format t "~S:~%" disk)
    (format t "  Sector size: ~:D octets.~%" (mezzano.supervisor:disk-sector-size disk))
    (format t "   Total size: ~:D sectors.~%" (mezzano.supervisor:disk-n-sectors disk))
    (format t "               ~:D octets.~%" (* (mezzano.supervisor:disk-n-sectors disk) (mezzano.supervisor:disk-sector-size disk)))))

(defclass peek-window ()
  ((%window :initarg :window :reader window)
   (%mode :initarg :mode :accessor mode)
   (%redraw :initarg :redraw :accessor redraw)
   (%frame :initarg :frame :reader frame)
   (%text-pane :initarg :text-pane :reader text-pane))
  (:default-initargs :mode 'peek-help :redraw t))

(defgeneric dispatch-event (peek event)
  ;; Eat unknown events.
  (:method (w e)))

(defmethod dispatch-event (peek (event mezzano.gui.compositor:window-activation-event))
  (setf (mezzano.gui.widgets:activep (frame peek)) (mezzano.gui.compositor:state event))
  (mezzano.gui.widgets:draw-frame (frame peek)))

(defmethod dispatch-event (peek (event mezzano.gui.compositor:key-event))
  (when (not (mezzano.gui.compositor:key-releasep event))
    (let* ((ch (mezzano.gui.compositor:key-key event))
           (cmd (assoc ch *peek-commands* :test 'char-equal)))
      (cond ((char= ch #\Space)
             ;; refresh current window
             (setf (redraw peek) t))
            ((char-equal ch #\Q)
             (throw 'quit nil))
            (cmd
             (setf (mode peek) (third cmd)
                   (redraw peek) t))))))

(defmethod dispatch-event (peek (event mezzano.gui.compositor:mouse-event))
  (handler-case
      (mezzano.gui.widgets:frame-mouse-event (frame peek) event)
    (mezzano.gui.widgets:close-button-clicked ()
      (throw 'quit nil))))

(defmethod dispatch-event (peek (event mezzano.gui.compositor:window-close-event))
  (throw 'quit nil))

(defun peek-main ()
  (catch 'quit
    (mezzano.gui.font:with-font (font mezzano.gui.font:*default-monospace-font* mezzano.gui.font:*default-monospace-font-size*)
      (let ((fifo (mezzano.supervisor:make-fifo 50)))
        (mezzano.gui.compositor:with-window (window fifo 640 700)
          (let* ((framebuffer (mezzano.gui.compositor:window-buffer window))
                 (frame (make-instance 'mezzano.gui.widgets:frame
                                       :framebuffer framebuffer
                                       :title "Peek"
                                       :close-button-p t
                                       :damage-function (mezzano.gui.widgets:default-damage-function window)))
                 (peek (make-instance 'peek-window
                                      :window window
                                      :frame frame))
                 (text-pane (make-instance 'mezzano.gui.widgets:text-widget
                                           :font font
                                           :framebuffer framebuffer
                                           :x-position (nth-value 0 (mezzano.gui.widgets:frame-size frame))
                                           :y-position (nth-value 2 (mezzano.gui.widgets:frame-size frame))
                                           :width (- (mezzano.gui.compositor:width window)
                                                     (nth-value 0 (mezzano.gui.widgets:frame-size frame))
                                                     (nth-value 1 (mezzano.gui.widgets:frame-size frame)))
                                           :height (- (mezzano.gui.compositor:height window)
                                                      (nth-value 2 (mezzano.gui.widgets:frame-size frame))
                                                      (nth-value 3 (mezzano.gui.widgets:frame-size frame)))
                                           :damage-function (lambda (&rest args)
                                                              (loop
                                                                 (let ((ev (mezzano.supervisor:fifo-pop fifo nil)))
                                                                   (when (not ev) (return))
                                                                   (dispatch-event peek ev)))
                                                              (apply #'mezzano.gui.compositor:damage-window window args)))))
            (setf (slot-value peek '%text-pane) text-pane)
            (mezzano.gui.widgets:draw-frame frame)
            (mezzano.gui.compositor:damage-window window
                                                  0 0
                                                  (mezzano.gui.compositor:width window)
                                                  (mezzano.gui.compositor:height window))
            (loop
               (when (redraw peek)
                 (let ((*standard-output* text-pane))
                   (setf (redraw peek) nil)
                   (mezzano.gui.widgets:reset *standard-output*)
                   (print-header)
                   (fresh-line)
                   (ignore-errors
                     (funcall (mode peek)))))
               (dispatch-event peek (mezzano.supervisor:fifo-pop fifo)))))))))

(defun spawn ()
  (mezzano.supervisor:make-thread 'peek-main
                                  :name "Peek"))
