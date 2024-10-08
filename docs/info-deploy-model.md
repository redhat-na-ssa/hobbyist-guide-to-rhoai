# Where do you deploy models?

1. Huge data centers
   1. Access model via remote call / REST API
   2. It might not be feasible to deploy a model to a server in environments where prediction latency is super-important or when a network connection may not always be available.
   3. Where prediction latency will not work (e.g. autonomous cars)
   4. The system is able to take actions based on predictions made in near real-time, and it can't wait for a server round-trip
   5. Latency might not be as important where it's critical that the model is as accurate as possible, for example, a disease diagnosis.
2. Embedded devices (mobile phone, etc.)
   1. Access model locally on device where the system can take actions near real time
   2. Large complex models cannot be deployed to edge devices
      1. Average GPU is < 4GB
      2. Average 1x-GPU shared by other apps
      3. Use for accelerated process will drain battery quickly
      4. Average android app storage < 11MB
      5. Exmaple:
         1. MobileNet - designed for mobile devices computer vision
            1. Now they may not have the highest number of predictive classes, and they may not be state of the art in recognition. But all of the work in performing trade-offs for the best mobile model had been done for you already and you can build on this.
