
;;;; Cologni Davide Matricola 830177
;;;; Cestari Davide Matricola 829626
;;;; Bertolotti Giorgio Matricola 829613

(defun access-cell (mem address)
  (nth (mod address 100) mem))

(defun halted-p (state)
  (eq (car state) 'halted-state))

(defun get-param (param)
  (lambda (state)
    (getf (cdr state) param)))

(defun get-acc (state)
  (funcall (get-param :acc) state))
(defun get-pc (state)
  (funcall (get-param :pc) state))
(defun get-mem (state)
  (funcall (get-param :mem) state))
(defun get-in (state)
  (funcall (get-param :in) state))
(defun get-out (state)
  (funcall (get-param ':out) state))
(defun get-flag (state)
  (funcall (get-param ':flag) state))

(defun create-state (acc pc mem in out flag)
  (list 'state
	:acc  acc
	:pc   pc
	:mem  mem
	:in   in
	:out  out
	:flag flag))

(defun or-default (value supplier)
  (if value
      value
    (funcall supplier)))

(defun state-with (state &key acc pc mem in out flag)
  (create-state
   (or-default acc
	       (lambda ()
		 (get-acc state)))
   (or-default pc
	       (lambda ()
		 (get-pc state)))
   (or-default mem
	       (lambda ()
		 (get-mem state)))
   (or-default in
	       (lambda ()
		 (get-in state)))
   (or-default out
	       (lambda ()
		 (get-out state)))
   (or-default flag
	       (lambda ()
		 (get-flag state)))))

(defun add-instr (xx state)
  (let* ((acc (get-acc state))
  	 (mem (get-mem state))
  	 (mem-val (access-cell mem xx))
	 (new-acc (mod (+ acc mem-val) 1000))
	 (new-flag (if (> (+ acc mem-val) 999)
		       'flag
		     'noflag))
	 (new-pc (+ 1 (get-pc state))))
    (state-with state
		:acc  new-acc
		:pc   new-pc
		:flag new-flag)))

(defun sub-instr (xx state)
  (let* ((acc (get-acc state))
  	 (mem (get-mem state))
  	 (mem-val (access-cell mem xx))
	 (new-acc (mod (- acc mem-val) 1000))
	 (new-flag (if (< (- acc mem-val) 0)
		       'flag
		     'noflag))
	 (new-pc (+ 1 (get-pc state))))
    (state-with state
		:acc  new-acc
		:pc   new-pc
		:flag new-flag)))

(defun sta-instr (xx state)
  (let* ((new-pc (+ 1 (get-pc state)))
	 (mem (get-mem state))
	 (acc (get-acc state)))
    (progn 
      (setf 
       (nth xx mem)
       acc)
      (state-with state
		  :pc new-pc
		  :mem mem))))

(defun lda-instr (xx state)
  (let* ((new-pc (+ 1 (get-pc state)))
	 (new-acc (nth xx
		       (get-mem state))))
    (state-with state
		:pc new-pc
		:acc new-acc)))

; unconditional jump
(defun bra-instr (xx state)
  (state-with state :pc xx))

(defun brz-instr (xx state)
  (let* ((acc (get-acc state))
	 (flag (get-flag state))
	 (new-pc (+ 1 (get-pc state))))
    (if (and (eql acc 0) (eq flag 'noflag))
	(state-with state :pc xx)
      (state-with state :pc new-pc))))

(defun brp-instr (xx state)
  (let* ((flag (get-flag state))
	 (new-pc (+ 1 (get-pc state))))
    (if (eq flag 'noflag)
	(state-with state :pc xx)
      (state-with state :pc new-pc))))

(defun inp-instr (state)
  (let* ((new-pc (+ 1 (get-pc state)))
	 (in (get-in state))
	 (new-acc (car in))
	 (new-in (cdr in)))
    (state-with state
		:acc new-acc
		:pc new-pc
		:in new-in)))

(defun out-instr (state)
  (let* ((new-pc (+ 1 (get-pc state)))
	 (out (get-out state))
	 (acc (get-acc state)))
    (state-with state
		:pc new-pc
		:out (append out (list acc)))))

(defun hlt-instr (state)
  (cons 'halted-state
	(cdr state)))

(defun run-instruction (instruction state)
  (let* ((xx (mod instruction 100))
	 (code (floor instruction 100)))
    (cond ((= code 1) (add-instr xx state))
	  ((= code 2) (sub-instr xx state))
	  ((= code 3) (sta-instr xx state))
	  ((= code 5) (lda-instr xx state))
	  ((= code 6) (bra-instr xx state))
	  ((= code 7) (brz-instr xx state))
	  ((= code 8) (brp-instr xx state))
	  ((and (= code 9) (= xx 1)) (inp-instr state))
	  ((and (= code 9) (= xx 2)) (out-instr state))
	  ((= code 0) (hlt-instr state))
	  (T (error "Illegal instruction.")))))

(defun fetch-instruction (state)
  (access-cell
   (get-mem state)
   (get-pc state)))

(defun one-instruction (state)
  (run-instruction 
   (fetch-instruction state)
   state))

(defun execution-loop (state)
  (if (halted-p state)
      state
    (execution-loop
     (one-instruction state))))

(defun remove-comment (line)
  (let ((start-comment (search "//" line)))
    (if start-comment
	(subseq line 0 start-comment)
      line)))

(defun empty-string-p (str)
  (= (length str) 0))

(defun format-lines (lines)
  (remove-if
   (lambda (x)
     (empty-string-p x))
   (mapcar
    (lambda (line)
      (string-trim " "
		   (remove-comment line)))
    lines)))

(defun unary-instruction-p (str)
  (find-if
   (lambda (x) (string-equal x str))
   '("inp" "out" "hlt")))

;the function name is called binary because implies
;the state as second parameter of the instruction
(defun binary-instruction-p (str)
  (find-if
   (lambda (x) (string-equal x str))
   '("add" "sub" "sta" "lda" "bra" "brz" "brp")))

(defun instruction-p (str)
  (or (string-equal str "dat")
      (binary-instruction-p str)
      (unary-instruction-p str)))

; (per ora) suppose all is not a instruction is a valid label
(defun label-p (str)
  (not (instruction-p str)))

(defun whitespace-p (c)
  (or (eql c #\Space)
      (eql c #\Tab)
      (eql c #\Newline)))

(defun tokenize (str)
  (if (empty-string-p str)
      nil
    (let* ((index (position-if 'whitespace-p str)))
      (if (null index)
	  (list str)
	(let* ((substr (subseq str 0 index))
	       (str-rest (subseq str (+ 1 index))))
	  (if (empty-string-p substr)
	      (tokenize str-rest)
	    (cons substr (tokenize str-rest))))))))

(defstruct binary-instr type arg)
(defstruct unary-instr type)
(defstruct label-decl name instr)
(defstruct label-ref name)

(defun parse-arguments (tokens)
  (if (null (cdr tokens))
      (let ((arg-num (parse-integer (car tokens) :junk-allowed t)))
	(if (numberp arg-num)
	    (if (and (>= arg-num 0) (<= arg-num 999))
		arg-num
	      (error "arguments must be between 0 and 999"))
	  (if (label-p (car tokens))
	      (make-label-ref :name (car tokens))
	    (error "syntax error: ~S is not a number and is not a valid label"
		   (car tokens)))))
    (error "syntax error: only one argument accepted")))

(defun parse-instruction (tokens)
  (cond ((null tokens) (error "syntax error: can't parse blank instruction"))
	((unary-instruction-p (car tokens))
	 (if (null (cdr tokens))
	     (make-unary-instr :type (car tokens))
	   (error "the instruction ~S doesn't accept argument" (car tokens))))
	((binary-instruction-p (car tokens))
	 (make-binary-instr :type (car tokens)
			    :arg (parse-arguments (cdr tokens))))
	((instruction-p (car tokens))
	 (if (null (cdr tokens))
	     (make-unary-instr :type (car tokens))
	   (make-binary-instr :type (car tokens)
			      :arg (parse-arguments (cdr tokens)))))
	(T (error "syntax error: unknown instruction ~S" (car tokens)))))

(defun parse-line (tokens)
  (cond ((label-p (car tokens))
	 (make-label-decl :name (car tokens)
			  :instr (parse-instruction (cdr tokens))))
	((instruction-p (car tokens))
	 (parse-instruction tokens))
	(T (error "syntax error: unknown token ~S" (car tokens)))))

(defun my-read-line (stream)
  (let ((res (read-char stream nil)))
    (if (null res)
	nil
      (if (or (eql #\Newline res) (eql #\Return res))
	  ""
	(concatenate 'string
		     (coerce (list res) 'string)
		     (my-read-line stream))))))

(defun read-all-lines (stream)
  (let ((res (my-read-line stream)))
    (if (null res)
	res
      (cons res (read-all-lines stream)))))

(defun fst (a b)
  ;; use this implementation instead of simply returning a
  ;; for suppress warning
  (car (cons a b)))

(defun read-file (filename)
  (let ((in (open filename)))
    (fst (format-lines
	  (read-all-lines in))
	 (close in))))

(defun parse-lmc (filename)
  (mapcar
   (lambda (line)
     (parse-line
      (tokenize line)))
   (read-file filename)))

(defun to-instruction-code (instr)
  (if (unary-instr-p instr)
      (let ((instr-name (unary-instr-type instr)))
	(cond ((string-equal instr-name "inp") 901)
	      ((string-equal instr-name "out") 902)
	      ((or (string-equal instr-name "hlt")
		   (string-equal instr-name "dat")) 0)
	      (T (error "error: unknow unary instruction ~S "
			instr-name))))
    (if (binary-instr-p instr)
	(let ((instr-name (binary-instr-type instr))
	      (instr-arg  (binary-instr-arg  instr)))
	  (cond ((string-equal instr-name "add")
		 (+ 100 instr-arg))
		((string-equal instr-name "sub")
		 (+ 200 instr-arg))
		((string-equal instr-name "sta")
		 (+ 300 instr-arg))
		((string-equal instr-name "lda")
		 (+ 500 instr-arg))
		((string-equal instr-name "bra")
		 (+ 600 instr-arg))
		((string-equal instr-name "brz")
		 (+ 700 instr-arg))
		((string-equal instr-name "brp")
		 (+ 800 instr-arg))
		((string-equal instr-name "dat") instr-arg)))
      (error "error: the parameter must be a binary-instr or unary-inst"))))

(defun lookup-label-dict (label dict)
  (if (or (null dict)
	  (empty-string-p label))
      nil
    (if (string-equal label
		      (car (car dict)))
	(cdr (car dict))
      (lookup-label-dict label (cdr dict)))))


(defun add-label-to-dict (label-name index dict)
  (if (null (lookup-label-dict label-name dict))
      (cons (cons label-name index)
	    dict)
    (error "error: the declaration of the label named ~S occurred more times"
	   label-name)))

(defun create-label-dict (instructions &optional (index 0))
  (if (null instructions)
      nil
    (let ((instr (car instructions)))
      (if (label-decl-p instr)
	  (add-label-to-dict (label-decl-name instr)
			     index
			     (create-label-dict (cdr instructions)
						(+ 1 index)))
	(create-label-dict (cdr instructions)
			   (+ 1 index))))))

(defun remove-label-decl (instructions)
  (if (null instructions)
      nil
    (let ((instr (car instructions)))
      (cons
       (if (label-decl-p instr)
	   (label-decl-instr instr)
	 instr)
       (remove-label-decl (cdr instructions))))))

(defun binary-instr-has-ref-p (instr)
  (label-ref-p
   (binary-instr-arg instr)))

(defun bynary-instr-ref-name (instr)
  (label-ref-name (binary-instr-arg instr)))

(defun link-label-refs (dict instructions)
  (mapcar
   (lambda (instr)
     (if (binary-instr-p instr)
	 (if (binary-instr-has-ref-p instr)
	     (if (string-equal (binary-instr-type instr)
			       "dat")
		 (error "error: dat instruction can't have a label argument")
	       (make-binary-instr
		:type (binary-instr-type instr)
		:arg  (lookup-label-dict (bynary-instr-ref-name instr)
					 dict)))
	   instr)
       instr))
   instructions))

(defun link (instructions)
  (link-label-refs
   (create-label-dict instructions)
   (remove-label-decl instructions)))

; given a list of number add 0 (empty instruction) to the end of the list
; and if the length of the list exceed 100 fail
(defun format-mem (instructions &optional (index 0))
  (if (< index 100)
      (if (null instructions)
	  (make-list (- 100 index)
		     :initial-element 0)
	(cons (car instructions)
	      (format-mem (cdr instructions)
			  (+ index 1))))
    (error "the memory should be bigger than 100 cell"))) 

(defun lmc-load (filename)
  (format-mem
   (mapcar
    'to-instruction-code
    (link
     (parse-lmc filename)))))

(defun lmc-run (filename input-queue)
  (get-out
   (execution-loop
    (create-state 0
		  0
		  (lmc-load filename)
		  input-queue
		  '()
		  'noflag))))
