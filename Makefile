compile: #rom colmix hexfiles
	jtcore -mr scratch
	@rmdir mist sidi

copy:
	scp Scratch.mra root@192.168.1.118:/media/fat/
	scp mister/output_1/jtscratch.rbf root@192.168.1.118:/media/fat/cores/

clean:
	rm -rf log/ mist/ mister/ sidi/

.PHONY: compile copy clean
