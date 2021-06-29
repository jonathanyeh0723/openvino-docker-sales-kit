import subprocess
import re

#cmd = 'python3 /opt/intel/openvino/deployment_tools/tools/benchmark_tool/benchmark_app.py -m /mnt/openvino_models/public/yolo-v3-tf/FP16-INT8/yolo-v3-tf.xml -d CPU -api async -t 1' 

fp = open('benchmark_models_cmds.txt', "r")
for cmd in iter(fp):
    print("cmd:{}".format(cmd))
    stdoutdata = subprocess.getoutput(cmd)
    for item in stdoutdata.split("\n"):
      if "Latency" in item:
          print(item)
      elif "Throughput" in item:
          print(item)
      elif "Read network" in item:
          print(item)
      elif "Load network" in item:
          print(item)
      elif "First inference" in item:
          print(item)
      elif "DNN" in item:
          print(item)
      elif "Measuring" in item:
          print(item)

fp.close()
