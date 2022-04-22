import gleam/iterator
import gleam/result
import parse.{Day}
import gleam/otp/task.{Task}
import gleam/erlang
import gleam/pair
import gleam/list
import gleam/result
import gleam/int

pub type Timing {
  Endless
  Ending(Timeout)
}

pub type Timeout =
  Int

pub fn exec(
  days: List(Day),
  timing: Timing,
  do: fn(Day) -> Result(a, b),
  other: fn(String) -> b,
  collect: fn(#(Day, Result(a, b))) -> String,
) -> List(String) {
  days
  |> task_map(do)
  |> try_await_many(timing)
  |> iterator.from_list()
  |> iterator.map(fn(x) {
    x
    |> pair.map_second(result.map_error(_, other))
    |> pair.map_second(result.flatten)
  })
  |> iterator.map(collect)
  |> iterator.to_list()
}

fn now_ms() {
  erlang.system_time(erlang.Millisecond)
}

fn task_map(over l: List(a), with f: fn(a) -> b) -> List(#(a, Task(b))) {
  list.map(l, fn(x) { #(x, task.async(fn() { f(x) })) })
}

fn try_await_many(
  tasks: List(#(x, Task(a))),
  timing: Timing,
) -> List(#(x, Result(a, String))) {
  case timing {
    Endless -> pair.map_second(_, fn(t) {
      task.try_await_forever(t)
      |> result.map_error(await_err_to_string)
    })

    Ending(timeout) -> {
      let end = now_ms() + timeout
      pair.map_second(_, fn(t: Task(a)) {
        end - now_ms()
        |> int.clamp(min: 0, max: timeout)
        |> task.try_await(t, _)
        |> result.map_error(await_err_to_string)
      })
    }
  }
  |> list.map(tasks, _)
}

fn await_err_to_string(err: task.AwaitError) -> String {
  case err {
    task.Timeout -> "task timed out"
    task.Exit(_) -> "task exited for some reason"
  }
}
