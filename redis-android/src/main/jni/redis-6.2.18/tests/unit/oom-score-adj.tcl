set system_name [string tolower [exec uname -s]]

if {$system_name eq {linux}} {
    start_server {tags {"oom-score-adj"}} {
        proc get_oom_score_adj {{pid ""}} {
            if {$pid == ""} {
                set pid [srv 0 pid]
            }
            set fd [open "/proc/$pid/oom_score_adj" "r"]
            set val [gets $fd]
            close $fd

            return $val
        }

        test {CONFIG SET oom-score-adj works as expected} {
            set base [get_oom_score_adj]

            # Enable oom-score-adj, check defaults
            r config set oom-score-adj-values "10 20 30"
            r config set oom-score-adj yes

            assert {[get_oom_score_adj] == [expr $base + 10]}

            # Modify current class
            r config set oom-score-adj-values "15 20 30"
            assert {[get_oom_score_adj] == [expr $base + 15]}

            # Check replica class
            r replicaof localhost 1
            assert {[get_oom_score_adj] == [expr $base + 20]}
            r replicaof no one
            assert {[get_oom_score_adj] == [expr $base + 15]}

            # Check child process
            r set key-a value-a
            r config set rdb-key-save-delay 1000000
            r bgsave

            set child_pid [get_child_pid 0]
            # Wait until background child process to setOOMScoreAdj success.
            wait_for_condition 100 10 {
                [get_oom_score_adj $child_pid] == [expr $base + 30]
            } else {
                fail "Set oom-score-adj of background child process is not ok"
            }
        }

        # Determine whether the current user is unprivileged
        set original_value [exec cat /proc/self/oom_score_adj]
        catch {
            set fd [open "/proc/self/oom_score_adj" "w"]
            puts $fd -1000
            close $fd
        } e
        # Failed oom-score-adj tests can only run unprivileged
        if {[string match "*permission denied*" $e]} {
            test {CONFIG SET oom-score-adj handles configuration failures} {
                # Bad config
                r config set oom-score-adj no
                r config set oom-score-adj-values "-1000 -1000 -1000"

                # Make sure it fails
                catch {r config set oom-score-adj yes} e
                assert_match {*Failed to set*} $e

                # Make sure it remains off
                assert {[r config get oom-score-adj] == "oom-score-adj no"}

                # Fix config
                r config set oom-score-adj-values "0 100 100"
                r config set oom-score-adj yes

                # Make sure it fails
                catch {r config set oom-score-adj-values "-1000 -1000 -1000"} e
                assert_match {*Failed*} $e

                # Make sure previous values remain
                assert {[r config get oom-score-adj-values] == {oom-score-adj-values {0 100 100}}}
            }
        } else {
            # Restore the original oom_score_adj value
            set fd [open "/proc/self/oom_score_adj" "w"]
            puts $fd $original_value
            close $fd
        }
    }
}
