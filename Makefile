compile: #rom colmix hexfiles
	jtcore -mr scratch
	@rmdir mist sidi

copy:
	scp mister/output_1/jtscratch.rbf root@192.168.1.118:/media/fat/

clean:
	rm -rf log/ mist/ mister/ sidi/

.PHONY: compile copy clean
