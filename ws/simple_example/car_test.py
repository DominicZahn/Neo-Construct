import numpy as np
import casadi

import pinocchio as pin
from pinocchio.visualize import MeshcatVisualizer
import pinocchio.casadi as cpin

robot = pin.RobotWrapper()
robot = pin.RobotWrapper.BuildFromURDF("carlikebot.urdf")

print(robot.model)
robot.setVisualizer(MeshcatVisualizer())
robot.initViewer()
robot.loadViewerModel("pinocchio")
robot.display(robot.q0)

cmodel = cpin.Model(robot.model)
cdata = cmodel.createData()

breakpoint()