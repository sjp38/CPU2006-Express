/*
 * specinvoke - run and accurately time lists of commands
 * Copyright(C) 1998-2003 Standard Performance Evaluation Corporation
 * All Rights Reserved
 *
 * unix.c: Functions for UNIX and UNIX-like systems
 *
 * $Id: unix.c 6387 2011-03-24 19:18:51Z cloyce $
 */

#include "specinvoke.h"

static char *versionid="1.0";
static char *rcsid="$Id: unix.c 6387 2011-03-24 19:18:51Z cloyce $";

extern int debug;  /* From specinvoke.c */

void init_state(specinvoke_state_t *si) {
  si->invoke_args = malloc(4 * sizeof (char *));
  if (si->invoke_args == NULL) {
    fprintf(stderr, "Could not allocate storage for state structure: %s(%d)\n",
	    STRERROR(errno), errno);
    exit(1);
  }
  si->invoke_args[0] = "/bin/sh";
  si->invoke_args[1] = "-c";
  si->invoke_args[2] = "replace_me";
  si->invoke_args[3] = 0;
  si->command_ptr = &(si->invoke_args[2]);
  si->shell       = "/bin/sh";
}

void init_os(int num) {
}
void reinit_os() {
}
void cleanup_os() {
}
pid_t invoke(copy_info_t *ui, command_info_t *ci, char **env,
	     specinvoke_state_t *si) {
    pid_t pid;
    char *dir = (ui->dir == NULL)?ci->dir:ui->dir;
    char *cmd = ci->cmd,
         *tmpcmd = NULL,
         *numbuf = NULL;
    int  infd;

    if (si->dry_run)
	return dry_invoke(ui, ci, si);

    /* Do bind variable subtitution */
    if (ui->bind != 0) {
        tmpcmd = sub_strings(cmd, BINDSTRVAR, ui->bind);
        if (cmd != ci->cmd)
          free(cmd);
        cmd = tmpcmd;
    }

    /* Do copy number subtitution */
    numbuf = make_number_buf(ui->num);
    if (numbuf != NULL) {
        tmpcmd = sub_strings(cmd, COPYNUMVAR, numbuf);
        if (cmd != ci->cmd)
          free(cmd);
        cmd = tmpcmd;
        free(numbuf);
    }

    if (cmd == ci->cmd) {
      /* Make a free()able copy */
      cmd = strdup(ci->cmd);
    }

    gettime(&(ui->start_time));
#if defined(PERFMON)
    pm_pre_spawn(ci, ui, &(si->pm_state));
#endif
    if ((pid = fork()) < 0) { /* Error */
	fprintf (stderr, "Can't fork: %s(%d)\n", STRERROR(errno), errno);
	specinvoke_exit (2, si);
    } else if (pid == 0) {  /* Child */
	if (dir && chdir (dir)) {
	    fprintf (stderr, "Can't change directory to '%s': %s(%d)\n", 
		     dir, STRERROR(errno), errno);
	    specinvoke_exit (1, si);
	}

	if (si->redir) {
	  if (ci->err != NULL) {
	    int errfd = open(ci->err, O_WRONLY|O_CREAT|O_APPEND, 0644);
	    if (errfd < 0) {
	      fprintf (stderr, "Can't open error file '%s': %s(%d)\n", 
		       ci->err, STRERROR(errno), errno);
	      specinvoke_exit (1, si);
	    }
	    fflush(stderr);
	    close(2);
	    dup(errfd);
	    close(errfd);
	  }

	  close(0);
	  if (ci->input != NULL) {
	    infd = open(ci->input, O_RDONLY);
	    if (infd < 0) {
	      fprintf (stderr, "Can't open input file '%s': %s(%d)\n", 
		       ci->input, STRERROR(errno), errno);
	      specinvoke_exit (1, si);
	    }
	  } else {
	    if (si->no_stdin == NUL) {
	      /* Attach stdin to /dev/null */
	      infd = open("/dev/null", O_RDONLY);
	      if (infd < 0) {
		fprintf (stderr, "Can't open /dev/null for stdin: %s(%d)\n", 
			 STRERROR(errno), errno);
		specinvoke_exit (1, si);
	      }
	    } else if (si->no_stdin == ZEROFILE) {
	      /* Attach stdin to a zero-length file */
	      char tmpfile[255];
	      sprintf(tmpfile, "spec_empty_file.%u.%ld", ui->num, (long)(ui->pid));
	      if (tmpfile == NULL) {	
		fprintf (stderr, "Can't create zero-length temporary filename\n ");
		specinvoke_exit (1, si);
	      }
	      infd = open(tmpfile, O_RDWR|O_CREAT|O_TRUNC, 0666);
	      if (infd < 0) {
		fprintf (stderr, "Can't create %s for stdin: %s(%d)\n",
			 tmpfile, STRERROR(errno), errno);
		specinvoke_exit (1, si);
	      }
	      unlink(tmpfile); /* Don't leave it lying around */
	    } else {
	      /* Punt (or CLOSE specifically specified) */
	      dup(2);
            }
	  }

	  close(1);
	  if (ci->output != NULL) {
	    int outfd = open(ci->output, O_WRONLY|O_CREAT|O_TRUNC, 0644);
	    if (outfd < 0) {
	      fprintf (stderr, "Can't open output file '%s': %s(%d)\n", 
		       ci->output, STRERROR(errno), errno);
	      specinvoke_exit (1, si);
	    }
	  } else {
	    dup(2);
	  }
	}

	/* We could redirect them here.  This might be useful for VMS? */
	*(si->command_ptr) = cmd;
	si->invoke_args[0] = si->shell;
#if defined(PERFMON)
	pm_pre_exec(ci, ui, &(si->pm_state));
#endif
	execve(si->shell, si->invoke_args, env);
    } else { /* Parent */
	ui->pid = pid;
#if defined(PERFMON)
	pm_post_spawn(pid, ci, ui, &(si->pm_state));
#endif
	fprintf (si->outfp,
                 "child started: %u, %u, %u, pid=%ld, '%s'\n", ui->num,
		 (unsigned int) ui->start_time.sec,
		 (unsigned int) ui->start_time.nsec, (long)(ui->pid), cmd);
	free(cmd); /* No sense wasting memory */
    }
    return pid;
}

long wait_for_next (long *status, int nowait) {
    int real_status;
    long pid;
    if (nowait) {
	pid = waitpid(-1, &real_status, WNOHANG);
    } else {
	pid = wait(&real_status);
    }
    *status = real_status;
    return pid;
}

void gettime(spec_time_t *t) {
    struct timeval tv;
    struct timezone tz;
    gettimeofday(&tv, &tz); 
    t->sec = tv.tv_sec;
    t->nsec = tv.tv_usec * 1000;
}

long time_cal(void) {
    /* Attempt to figure out what resolution the gettimeofday() call supports.
     * The deltas will be in nanoseconds, even though gettimeofday only
     * returns microseconds at best.
     */
    #define TRIES 1000
    struct timeval time, prev;
    struct timezone tz;
    int i = 0, avg_count = 0, count, counts[TRIES];
    long avg_time = 0, deltas[TRIES];

    gettimeofday(&time, &tz); 
    prev.tv_sec = time.tv_sec;
    prev.tv_usec = time.tv_usec;

    for(i = 0; i < TRIES; i++) {
        count = 0;
	while (prev.tv_usec == time.tv_usec &&
	       prev.tv_sec  == time.tv_sec) {
	    gettimeofday(&time, &tz);
            count++;
	}
	deltas[i] = ((time.tv_sec - prev.tv_sec) * 1000000) + (time.tv_usec - prev.tv_usec);
	counts[i] = count;
        prev.tv_sec = time.tv_sec;
        prev.tv_usec = time.tv_usec;
    }
    for(i = 0; i < TRIES; i++) {
	avg_time += deltas[i];
	avg_count += counts[i];
	if (debug > 8)
          printf("time delta for iteration %d: %ldus (%d rounds)\n", i, deltas[i], counts[i]);
    }
    avg_count /= i;
    avg_time /= i;
    avg_time *= 1000;	/* Make it nanoseconds */
    if (debug)
        printf("specinvoke: calculated timer resolution (%d iterations): %ld ns (%d avg rounds)\n", i, avg_time, avg_count);

    return (avg_time);
}

int specmillisleep(time_t milliseconds) {

#if defined(HAVE_NANOSLEEP)
  /* The POSIX.1 nanosleep function is preferred */
  struct timespec sleeptime;
  int rc = 0;

  sleeptime.tv_sec = milliseconds / 1000;
  sleeptime.tv_nsec = (milliseconds % 1000) * 1000000;
  rc = nanosleep(&sleeptime, NULL);
  if (rc < 0 && errno == ENOSYS) {
    fprintf(stderr, "specinvoke configuration error: nanosleep(2) is not available!\n");
    specinvoke_exit(1, (specinvoke_state_t *)NULL);
  }
  return rc;
#elif defined(HAVE_USLEEP)
  /* But fall back to the usleep function if necessary */
  return usleep((unsigned int)(milliseconds * 1000));
#elif defined(HAVE_SELECT)
  struct timeval sleeptime;
  int rc = 0;
  sleeptime.tv_sec = milliseconds / 1000;
  sleeptime.tv_usec = (milliseconds % 1000) * 1000;
  return select(0, 0, 0, 0, &sleeptime);
#else
  /* Fail if none of nanosleep, usleep, or select are available */
# error There is no defined sleep function
#endif

}
