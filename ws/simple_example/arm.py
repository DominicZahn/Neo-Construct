import time, sys
import numpy as np
import matplotlib.pyplot as plt

import pinocchio as pin
from pinocchio import RobotWrapper
from pinocchio.visualize import MeshcatVisualizer
from pinocchio.visualize.meshcat_visualizer import meshcat
import pinocchio.casadi as cpin
import casadi as ca
from acados_template import (
    plot_trajectories,
    AcadosOcp,
    AcadosModel,
    AcadosOcpCost,
    AcadosOcpConstraints,
    AcadosOcpSolver,
)

p_target = np.array([0.5, 0.0, 0.5])


def setupVis(robot: RobotWrapper):
    # robot
    robot.setVisualizer(MeshcatVisualizer())
    robot.initViewer()
    robot.loadViewerModel("arm")
    robot.display(robot.q0)
    # target
    robot.viewer["target"].set_object(meshcat.geometry.Sphere(0.05))
    target_homo = np.eye(4)
    target_homo[:3, 3] = p_target
    robot.viewer["target"].set_transform(target_homo)
    # endeffector
    robot.viewer["p"].set_object(meshcat.geometry.Sphere(0.05))

def replayMotion(
    N: int,
    tf: float,
    robot: RobotWrapper,
    realtime_factor=1.0,
):
    dt = realtime_factor * tf / N
    while True:
        input("start visulization on input")
        print("i : cost_i | u_i")
        for i in range(N):
            # read / compute
            qi = solver.get(i, "x")[:nq]
            cpin.framesForwardKinematics(cmodel, cdata, ca.SX(qi))
            pi = cdata.oMf[-1].translation
            di = pi - p_target
            costi = ca.dot(di,di)
            ui = solver.get(i, "u")

            # display
            robot.display(qi)
            p_homo = np.eye(4)
            p_homo[:3, [3]] = np.array(ca.DM(pi))
            robot.viewer["p"].set_transform(p_homo)
            print(i, ":", costi, "|", np.round(ui, 3))
            time.sleep(dt)


def cost(ac_model: AcadosModel) -> AcadosOcpCost:
    ocp_cost = AcadosOcpCost()

    # tf: ||p - p_target||² (p: endeffector position)
    ocp_cost.cost_type_e = "NONLINEAR_LS"
    ac_model.cost_y_expr_e = p
    ocp_cost.yref_e = p_target
    ocp_cost.W_e = np.eye(3)

    return ocp_cost


def constraints(ac_model: AcadosModel) -> AcadosOcpConstraints:
    ocp_cons = AcadosOcpConstraints()

    # initial
    ocp_cons.x0 = np.zeros(nq * 2)

    # path
    #       limit controls
    tau_max = 1.0
    ocp_cons.idxbu = np.ones(nq)
    ocp_cons.ubu = np.full(nq, tau_max)
    ocp_cons.lbu = np.full(nq, -tau_max)
    #       limit velocities
    v_max = 1
    ocp_cons.idxbx = np.arange(nq,2*nq)
    ocp_cons.ubx = np.full(nq, v_max)
    ocp_cons.lbx = np.full(nq, -v_max)

    # terminal
    ocp_cons.idxbx_e = np.arange(nq,2*nq)
    ocp_cons.ubx_e = np.full(nq, 0.01)
    ocp_cons.lbx_e = np.full(nq, -0.01)
    return ocp_cons


# -----------------------------------------------------
robot = RobotWrapper()
robot = RobotWrapper.BuildFromURDF("arm.urdf")

cmodel = cpin.Model(robot.model)
cdata = cmodel.createData()
nq = cmodel.nq

# print robot info
q0 = ca.SX(robot.q0)
CoM = cpin.centerOfMass(cmodel, cdata, q0)
print('CoM:', CoM)

# linking between variables
q = ca.SX.sym("q", robot.nq)
qdot = ca.SX.sym("qdot", robot.nv)
tau = ca.SX.sym("tau", robot.nv)
cpin.aba(cmodel, cdata, q, qdot, tau)
qddot = cdata.ddq
cpin.framesForwardKinematics(cmodel, cdata, q)
p = cdata.oMf[-1].translation

# problem formulation
x = ca.vertcat(q, qdot)
xdot = ca.vertcat(qdot, qddot)
u = tau

# acados model
ocp = AcadosOcp()
ac_model = AcadosModel()
ac_model.name = "simple_arm"
ac_model.x = x
ac_model.u = u
ac_model.f_expl_expr = xdot

ocp.cost = cost(ac_model)
ocp.constraints = constraints(ac_model)

Tf = 1.0
N = 30
ocp.model = ac_model
ocp.solver_options.tf = Tf
ocp.solver_options.integrator_type = "ERK"
ocp.solver_options.N_horizon = N
ocp.solver_options.print_level = 3 # 4 for qp iters
ocp.solver_options.tol = 10**-5
ocp.solver_options.nlp_solver_max_iter = 1000

solver = AcadosOcpSolver(ocp)
solver.solve()
solver.print_statistics()
print("Cost:", solver.get_cost())

if solver.get_status() != 0:
    sys.exit(-1)

simX = np.zeros((N+1, ac_model.x.size1()))
simU = np.zeros((N, ac_model.u.size1()))
for i in range(N):
    simX[i,:] = solver.get(i, "x")
    simU[i,:] = solver.get(i, "u")
simX[N,:] = solver.get(N, "x")

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
    single_column=True,
    show_legend=False,
    show_plot=False # keep interactive
)
plt.ion()
plt.pause(1)

setupVis(robot)
replayMotion(N, Tf, robot, 1.0)