import gleam/json

pub type Lesson {
  Lesson(
    id: String,
    title: String,
    path: String,
    area: String,
    goal: String,
    questions: List(String),
  )
}

pub fn all() -> List(Lesson) {
  [
    Lesson(
      id: "boot",
      title: "Boot sequence",
      path: "init/main.c",
      area: "Initialization",
      goal: "Find the kernel entry flow and summarize the order of major initialization steps.",
      questions: [
        "Where does start_kernel() begin?",
        "Which setup functions must run before interrupts are enabled?",
        "Where is the first userspace process prepared?",
      ],
    ),
    Lesson(
      id: "scheduler",
      title: "Process scheduling",
      path: "kernel/sched/core.c",
      area: "Scheduler",
      goal: "Understand the scheduler's core responsibility before reading a specific scheduling class.",
      questions: [
        "What state is needed to choose the next task?",
        "Where does a context switch happen?",
        "Which invariants are protected by runqueue locks?",
      ],
    ),
    Lesson(
      id: "memory",
      title: "Virtual memory",
      path: "mm/memory.c",
      area: "Memory management",
      goal: "Trace a page-fault-related path and identify the boundary between generic MM and architecture code.",
      questions: [
        "Which data structures represent an address space?",
        "Where are page table entries inspected or changed?",
        "Which errors can propagate back to the fault handler?",
      ],
    ),
    Lesson(
      id: "vfs",
      title: "VFS read and write",
      path: "fs/read_write.c",
      area: "Virtual file system",
      goal: "Follow a read or write request from the syscall-facing layer toward a filesystem implementation.",
      questions: [
        "Which validation happens before file operations are called?",
        "How are offsets and byte counts updated?",
        "Where does the VFS dispatch to a concrete filesystem?",
      ],
    ),
    Lesson(
      id: "network",
      title: "Network device core",
      path: "net/core/dev.c",
      area: "Networking",
      goal: "Identify the central receive/transmit paths and the role of network devices and packet buffers.",
      questions: [
        "Where does an incoming packet enter the networking stack?",
        "How is work distributed between interrupt and deferred processing?",
        "Which path sends a packet to a network device driver?",
      ],
    ),
  ]
}

pub fn to_json() -> String {
  json.array(all(), of: encode_lesson)
  |> json.to_string
}

fn encode_lesson(lesson: Lesson) {
  json.object([
    #("id", json.string(lesson.id)),
    #("title", json.string(lesson.title)),
    #("path", json.string(lesson.path)),
    #("area", json.string(lesson.area)),
    #("goal", json.string(lesson.goal)),
    #("questions", json.array(lesson.questions, of: json.string)),
  ])
}
