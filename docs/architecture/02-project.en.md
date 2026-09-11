---
title: "02 Project: Embodied Application Workspace"
weight: 20
mermaid: true
---

A Project is the workspace where one embodied application is continuously developed, collaborated on, and run. Application content, environment, participants, and runtime history are connected in the Project, so users, Agents, and Robots keep working around the same goal.

Semantic Studio is the integrated tool for using a Project. Through Studio, users understand the Project, maintain the application, collaborate with Agents, and observe the environment and Robot actions.

~~~mermaid
flowchart LR
    User["User"] --> Studio["Semantic Studio"]
    Studio --> Project["Project<br/>embodied application workspace"]

    Project --> Application["Application"]
    Project --> Environment["Environment"]
    Project --> Collaboration["Collaboration"]
    Project --> Work["Work and runtime"]
~~~

## Project builds shared context around an embodied application

An embodied application turns a user goal into actions in a real or simulated environment. That process continuously goes through environment understanding, task organization, Robot execution, and result feedback.

A Project gives these activities a shared context:

- the user is discussing the business goal in the current Project;
- Agents understand the task from the current Project's application knowledge and environment information;
- Workflow organizes the work the current Project needs to advance;
- the Robot acts in the environment associated with the current Project;
- environment change and runtime results continue to return to the current Project.

For example, in a depalletizing Project, "the top tote", "the target pallet", and "the available Robot" all come from the same application. Users, Agents, and Robots form goals and execute actions around these objects, and they keep using the environment state after the actions.

## Application in a Project

The application defines the problems the Project needs to solve, and the knowledge and capabilities that can be used to finish those problems.

It can include:

- business goals and application logic;
- Agent Skills;
- Robot Skills;
- Scenes and Layouts;
- application-facing code, tests, and documents.

Agent Skills help Agents understand domain knowledge and working methods. Robot Skills express embodied operations such as navigation, grasp, and place. Scenes and Layouts describe the environment in which a Robot acts for a simulation application.

A Project can maintain application-specific content, and it can also choose capabilities and environment resources already published in Semantic. Together they make up the current application.

## Environment in a Project

The environment is the space where an embodied application happens. It can be a simulation Scene, or the workplace where a real Robot is.

Through the environment, a Project understands the following in the current world:

- Robots;
- objects;
- regions;
- spatial relations among objects;
- changes brought by Robot actions.

Semantic Map expresses objects, regions, and spatial relations in the environment. Feedback expresses the continuous progress of a Robot action. Observation provides an active inspection of the current state. Artifact stores resources such as images, depth, point clouds, video, models, reports, and logs.

Together, this information helps Agents understand goals, and it also lets users see how Robot actions affect the environment.

~~~text
Environment objects and spatial relations
→ Agents understand the goal
→ The Robot acts in the environment
→ Feedback and Observation return
→ The Project obtains new environment information
~~~

## Participants in a Project

Users, multiple Agents, and Robots take part in one embodied application together.

### User

The user proposes goals, adds business information, reviews plans, and stays involved when a choice or authorization is needed. The user can also inspect application content, the environment, and runtime results.

### Agent

Leader collaborates with the user and organizes the overall work. Other specialist Agents handle environment, development, runtime monitoring, or Robot tasks according to their roles.

Agents work with the application knowledge, environment information, and collaboration context that the Project provides. They exchange information related to the current goal through Conversation, Task, and runtime results.

### Robot

A Robot turns a task into actual actions in the environment. Robot Agent understands the current Robot Task and chooses a suitable Robot Skill. Robot Skill drives the Robot through Ability and Robot SDK to finish the operation.

The Project brings the Robot's capabilities and runtime results into the current application, so an Agent's task decisions stay connected to the actual Robot.

## Collaboration in a Project

Conversation is the main space where users collaborate with multiple Agents. In Conversation, a user can state a goal, refer to objects in the environment, answer Interactions, and inspect plans, questions, and results returned by Agents.

One Project can host multiple Conversations. Each Conversation keeps developing around its own topic, while sharing the current Project's application and environment background.

Collaboration among Agents also happens in Project context. Leader can hand different work to the suitable Agent. An Agent can use a predecessor Task result or request a short consultation. Important questions and results return to Conversation, so the user can understand how the current work is progressing.

## Work and runtime in a Project

A user goal is realized step by step through Plan, Workflow, and Robot execution.

A Plan expresses an Agent's understanding of the goal and the main work. Workflow organizes confirmed work so different Tasks can keep progressing from dependencies, resources, and runtime results.

After a Robot Task enters execution, Robot Agent chooses a Robot Skill, and the Robot finishes the action through the execution chain. Feedback, Observation, Artifact, and results produced by the action continue into Workflow and Conversation.

~~~mermaid
flowchart LR
    Conversation["Conversation"] --> Plan["Plan"]
    Plan --> Workflow["Workflow"]
    Workflow --> Task["Task"]
    Task --> Robot["Robot action"]
    Robot --> Result["Environment change and runtime result"]
    Result --> Workflow
    Result --> Conversation
~~~

This process connects user collaboration, Agent judgment, and Robot action. The Project keeps the relations among them, so each round of work can continue from existing goals and environment state.

## Continuity of a Project

An embodied application goes through many rounds of development, many runs, and continuous environment change. The Project runs through the whole evolution:

~~~text
Develop the application
→ Prepare the environment
→ Collaborate with Agents
→ Robot execution
→ Inspect the environment and runtime results
→ Keep adjusting the application
~~~

Application knowledge can keep improving with development. Conversation can keep discussing new goals. Semantic Map can express a new environment state. Runtime results and Artifacts can also enter later work.

After a Workflow finishes, the Project still hosts this embodied application. The user can start new work from the current environment, or adjust Skills, Scenes, or application logic from Robot runtime results.

## Project and reusable capabilities

Semantic provides reusable Agent Skills, Robot Skills, Scenes, Models, and Robot support capabilities. A Project chooses content that fits the current application from these capabilities, and uses it together with application-specific content.

For example, a depalletizing Project can use:

- an Agent Skill for depalletizing planning;
- semantic navigation, grasp, and place Robot Skills;
- R1 Pro Robot capabilities;
- a depalletizing simulation Scene;
- the Model chosen by the current application.

Reusable capabilities let a Project compose existing work. Application-specific content expresses the current business goals, environment, and working style.

## How Semantic Studio uses a Project

Semantic Studio presents the same Project from several working views.

~~~mermaid
flowchart LR
    Studio["Semantic Studio"]
    Project["Project"]

    Application["Application"]
    Environment["Environment"]
    Collaboration["Collaboration"]
    Work["Work"]
    Runtime["Runtime"]

    Studio --> Application
    Studio --> Environment
    Studio --> Collaboration
    Studio --> Work
    Studio --> Runtime

    Application --> Project
    Environment --> Project
    Collaboration --> Project
    Work --> Project
    Runtime --> Project
~~~

### Application view

The user inspects and maintains application logic, Agent Skills, Robot Skills, Scenes, tests, and documents.

### Environment view

The user inspects Scene, Viewer, and Semantic Map to understand the space where the Robot acts, and the objects and regions in it.

### Collaboration view

The user talks with Agents through Conversation, handles Interactions, and inspects plans and results returned by Agents.

### Work view

The user inspects Plan, Workflow, and Task to understand how the current goal is organized and advanced.

### Runtime view

The user inspects Robot, Robot Execution, Observation, and Artifact to understand the action the Robot is performing and the changes happening in the environment.

These views are connected through objects in the Project. A user can inspect an environment object mentioned in Conversation, open the corresponding Robot Execution from a Task, open an Artifact from an Observation, and then return to application content to keep developing.

Studio page structure and concrete operations are covered further in the Studio design and the user guide.

## A complete Project usage process

Take a depalletizing Project as an example:

1. The Project gathers the depalletizing application, Agent Skills, Robot Skills, and Scene.
2. The user opens the Project in Studio and inspects the current environment.
3. The user inspects totes and pallets in Semantic Map, and proposes a transfer goal in Conversation.
4. Agents form a Plan from application knowledge and environment information.
5. Workflow organizes the tasks. The Robot finishes navigation, grasp, transfer, and place.
6. Environment change, Observation, and Artifact return to the Project.
7. The user inspects the result and keeps adjusting Skills, Scenes, or application logic.
8. Later work continues from the updated Project and environment state.

Throughout the process, the Project keeps a continuous relation among application, environment, collaboration, and runtime. Semantic Studio gives users one tool for understanding and operating that content.

## Relation to later chapters

This chapter introduced the core design of Project as the workspace of an embodied application. Later chapters continue:

- **Environment, perception, and Semantic Map**: how environment information is formed and used;
- **Agents and collaboration**: how multiple Agents work around Conversation and Task;
- **Planning and Workflow**: how Plans and Tasks are formed and keep progressing;
- **Robot execution and the embodied loop**: how Robot Skill, Ability, and Robot SDK complete an action;
- **Semantic extension model**: how developers extend Agents, Skills, Robots, and Scenes;
- **Simulation, real robots, and deployment**: how an embodied application enters different runtime environments.

## Related layers

- Design contracts and extension guidance: [Core modules · Studio panels and interaction renderers](../developer/core-modules/interface/studio-panel.en.md)
- Server / frontend implementation details: [Internals · Studio frontend architecture](../developer/reference/internals/semantic-studio.en.md)
