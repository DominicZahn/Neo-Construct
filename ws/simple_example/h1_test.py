import numpy as np
import casadi as c
import time

import pinocchio as pin
from pinocchio import RobotWrapper
from pinocchio.visualize import MeshcatVisualizer
from pinocchio.visualize.meshcat_visualizer import meshcat

import pinocchio.casadi as cpin

from acados_template import (
    plot_trajectories,
    AcadosOcp,
    AcadosModel,
    AcadosOcpCost,
    AcadosOcpConstraints,
    AcadosOcpSolver,
)

""" 
q_neo_map = {}
q_neo_map['left_hip_pitch_joint'] = q_neo_map['right_hip_pitch_joint'] = 1.96648
q_neo_map['left_knee_joint'] = q_neo_map['right_knee_joint'] = 1.16915
q_neo_map['left_ankle_pitch_joint'] = q_neo_map['right_ankle_pitch_joint'] = -0.892202
q_neo_map['torso_joint'] = 1.47453
"""
q_neo_map = {}
q_neo_map["left_hip_pitch_joint"] = q_neo_map["right_hip_pitch_joint"] = 0
q_neo_map["left_knee_joint"] = q_neo_map["right_knee_joint"] = 0
q_neo_map["left_ankle_pitch_joint"] = q_neo_map["right_ankle_pitch_joint"] = 0.3
q_neo_map["torso_joint"] = 0

dynamic_joint_names = [
    "left_hip_pitch_joint",
    "right_hip_pitch_joint",
    "left_knee_joint",
    "right_knee_joint",
    "left_ankle_pitch_joint",
    "right_ankle_pitch_joint",
    "torso_joint",
]

CoM = np.array([0.0, 0.0, 0.0])
# -------------- Helper ----------------------


def setupVis(robot: RobotWrapper):
    # robot
    robot.setVisualizer(MeshcatVisualizer())
    robot.initViewer()
    robot.loadViewerModel("h1_2")
    robot.display(robot.q0)
    # CoM
    robot.viewer["CoM"].set_object(meshcat.geometry.Sphere(0.05))
    robot.viewer["CoM_proj"].set_object(meshcat.geometry.Sphere(0.05))
    robot.viewer["debug"].set_object(meshcat.geometry.Sphere(0.05))
    # DEBUG ankles
    robot.viewer["l_ankle"].set_object(meshcat.geometry.Sphere(0.05))
    robot.viewer["r_ankle"].set_object(meshcat.geometry.Sphere(0.05))
    robot.viewer["PoS_center"].set_object(meshcat.geometry.Sphere(0.05))

    return robot


def displayPoint(robot: RobotWrapper, pos: np.ndarray, vis_name: str):
    pos_homo = np.eye(4)
    pos_homo[:3, [3]] = pos
    robot.viewer[vis_name].set_transform(pos_homo)


def plotOCPSolution(ocp: AcadosOcp, N: int, Tf: float):
    simX = np.zeros((N + 1, x.size()[0]))
    simU = np.zeros((N, u.size()[0]))
    for i in range(N):
        simX[i, :] = solver.get(i, "x")
        simU[i, :] = solver.get(i, "u")
    simX[N, :] = solver.get(N, "x")

    plot_trajectories(
        x_traj_list=[simX],
        u_traj_list=[simU],
        time_traj_list=[np.linspace(0, Tf, N + 1)],
        labels_list=["OCP result"],
        idxbu=ocp.constraints.idxbu,
        lbu=ocp.constraints.lbu,
        ubu=ocp.constraints.ubu,
        X_ref=None,
        U_ref=None,
        x_min=None,
        x_max=None,
    )


def runVis(
    ocp_solver: AcadosOcpSolver,
    N: int,
    tf: float,
    robot: RobotWrapper,
    realtime_factor=1.0,
):
    dt = realtime_factor * tf / N
    while True:
        input("start visulization on input")
        print("i : qi | ui")
        for i in range(N):
            # read / compute
            qi = solver.get(i, "x")[:nq]
            cpin.framesForwardKinematics(cmodel, cdata, c.SX(qi))
            pi = cdata.oMf[-1].translation
            ui = solver.get(i, "u")

            # display
            robot.display(qi)
            p_homo = np.eye(4)
            p_homo[:3, [3]] = np.array(c.DM(c.pi))
            robot.viewer["p"].set_transform(p_homo)
            print(i, ":", qi, "\n", ui)
            time.sleep(dt)

            # TODO CoM, etc.
            """ displayPoint(robot,
             np.array(c.DM(l_ankle.translation)),
             'l_ankle') """
            """ displayPoint(robot,
             np.array(c.DM(r_ankle.translation)),
             'r_ankle') """
            """ displayPoint(robot,
            np.array(c.DM(PoS_center.translation)),
            'PoS_center') """
            """ displayPoint(robot,
            np.array(c.DM(CoM_proj)),
            'CoM_proj') """


# -------------- general ----------------------
def stdvec2list(stdvec) -> list:
    l = []
    for v in stdvec:
        l.append(v)
    return l


def fixJoints(
    robot: RobotWrapper, joint_names: list[str], joint_values: list[float] | None = None
) -> RobotWrapper:
    full_model = robot.model
    for joint_name in joint_names:
        if not full_model.existJointName(joint_name):
            print(
                "Warning: joint " + str(joint_name) + " does not belong to the model!"
            )
    return robot.buildReducedRobot(joint_names, joint_values)


def proj2PoS(PoS_center: cpin.SE3, p: c.SX) -> c.SX:
    v = p - PoS_center.translation
    PoS_normal = PoS_center.rotation @ c.SX([0, 0, 1])
    PoS_normal /= c.dot(PoS_normal, PoS_normal)
    dist = c.dot(v, PoS_normal)
    p_proj = p - dist * PoS_normal
    return p_proj


def stability(PoS_center, CoM_proj) -> c.SX:
    d = PoS_center.translation - CoM_proj
    return c.dot(d, d)


# -------------- OCP Def ----------------------
def cost(ac_model: AcadosModel) -> AcadosOcpCost:
    ocp_cost = AcadosOcpCost()
    ocp_cost.cost_type = "NONLINEAR_LS"

    cost_stability = stability(PoS_center, CoM_proj)
    ac_model.cost_y_expr = cost_stability
    ocp_cost.yref = 0.0
    ocp_cost.W = np.eye(1)

    return ocp_cost


def constraints(ac_model: AcadosModel) -> AcadosOcpConstraints:
    ocp_cons = AcadosOcpConstraints()

    # initial
    q_neo = np.zeros((robot.nq))
    for name, value in q_neo_map.items():
        id = robot.model.getJointId(name) - 1  # -1 for missing universe
        q_neo[id] = value

    ocp_cons.x0 = np.hstack((q_neo, np.zeros(nq)))

    # path
    #      torque limit
    ocp_cons.idxbu = np.ones(nq)
    tau_max = 360
    ocp_cons.ubu = np.full(nq, tau_max)
    ocp_cons.lbu = np.full(nq, -tau_max)
    #      joint limit
    qub = robot.model.upperPositionLimit
    qlb = robot.model.lowerPositionLimit
    ocp_cons.idxbx = np.arange(2 * nq)
    max_acceleration = 1
    ocp_cons.ubx = np.hstack((qub, np.full(nq, max_acceleration)))
    ocp_cons.lbx = np.hstack((qlb, np.full(nq, -max_acceleration)))

    # end
    #   head
    head_pos_proj = proj2PoS(PoS_center, head_pos)
    head_height = c.dot(head_pos - head_pos_proj, head_pos - head_pos_proj)
    ac_model.con_h_expr_e = head_height
    ocp_cons.uh_e = 0.8
    ocp_cons.lh_e = 0.0

    return ocp_cons


# -----------------------------------------------------
model_dir = (
    "/home/robot/ws/src/ros2_heinz/h1_gazebo_sim/ros_gz_h1_description/models/h1_ign/"
)
model_dir = ""
urdf_file = "h1_2_handless_foot_root.urdf"  # 'h1_2.urdf' 'h1_2_handless.urdf'
sdf_file = "model.sdf"
mesh_dir = "meshes/"
robot = pin.RobotWrapper()
robot = pin.RobotWrapper.BuildFromURDF(model_dir + urdf_file)

# fix not needed joints
fixed_joint_names = stdvec2list(robot.model.names)
fixed_joint_names.remove("universe")
for name in dynamic_joint_names:
    fixed_joint_names.remove(name)
robot = fixJoints(robot, fixed_joint_names)

print(robot.model)
setupVis(robot)

cmodel = cpin.Model(robot.model)
cdata = cmodel.createData()
nq = cmodel.nq

q = c.SX.sym("q", robot.nq)
qdot = c.SX.sym("qdot", robot.nv)
tau = c.SX.sym("tau", robot.nv)
cpin.aba(cmodel, cdata, q, qdot, tau)
qqdot = cdata.ddq

# CoM
cpin.framesForwardKinematics(cmodel, cdata, q)
CoM = cpin.centerOfMass(cmodel, cdata, q)
# PoS
l_ankle = cdata.oMf[13]  # left_ankle_roll_link
r_ankle = cdata.oMf[25]  # right_ankle_roll_link

PoS_center = cpin.SE3()
PoS_center.translation = (r_ankle.translation + l_ankle.translation) / 2
PoS_center.rotation = l_ankle.rotation
CoM_proj = proj2PoS(PoS_center, CoM)

# head (lidar_link)
id_head = robot.model.getFrameId("lidar_link")
head_pos = cdata.oMf[id_head].translation


# variable def
x = c.vertcat(q, qdot)
xdot = c.vertcat(qdot, tau)
u = tau

# acados model
ocp = AcadosOcp()
ac_model = AcadosModel()
ac_model.name = "h1_2"
ac_model.x = x
ac_model.u = u
ac_model.f_expl_expr = xdot

ocp.cost = cost(ac_model)
ocp.constraints = constraints(ac_model)

ocp.model = ac_model
ocp.solver_options.tf = 1.0
ocp.solver_options.integrator_type = "ERK"
ocp.solver_options.N_horizon = 33
ocp.solver_options.print_level = 1  # full verbosity

solver = AcadosOcpSolver(ocp)
solver.solve()
solver.print_statistics()
print("Cost:", solver.get_cost())

""" plotOCPSolution(
    ocp,
    ocp.solver_options.N_horizon,
    ocp.solver_options.tf)
"""
runVis(solver, ocp.solver_options.N_horizon, ocp.solver_options.tf, robot, 2.0)

