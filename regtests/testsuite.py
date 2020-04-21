#!/usr/bin/env python
#                              Ada Web Server
#
#                     Copyright (C) 2003-2020, AdaCore
#
#  This library is free software; you can redistribute it and/or modify
#  This is free software;  you can redistribute it  and/or modify it
#  under terms of the  GNU General Public License as published  by the
#  Free Software  Foundation;  either version12,  or (at your option) any
#  later version.  This software is distributed in the hope  that it will
#  be useful, but WITHOUT ANY WARRANTY;  without even the implied warranty
#  of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
#  General Public License for  more details.
#
#  You should have  received  a copy of the GNU General  Public  License
#  distributed  with  this  software;   see  file COPYING3.  If not, go
#  to http://www.gnu.org/licenses for a complete copy of the license.
"""
./testsuite.py [OPTIONS] [TEST_NAME]

This module is the main driver for AWS testsuite
"""
import logging
import os
import sys

from glob import glob
from makevar import MakeVar

from gnatpython.env import Env
from gnatpython.main import Main
from gnatpython.mainloop import (MainLoop, add_mainloop_options,
                                 generate_collect_result,
                                 generate_run_testcase,
                                 setup_result_dir)
from gnatpython.testdriver import add_run_test_options
from gnatpython.reports import ReportDiff


class Runner(object):
    """Run the testsuite

    Build a list of all subdirectories containing test.py then, for
    each test, parse the test.opt file (if exists) and run the test
    (by spawning a python process).
    """

    def __init__(self, options):
        """Fill the test lists"""

        # Various files needed or created by the testsuite
        setup_result_dir(options)
        self.options = options

        # Always add ALL and target info
        self.discs = ['ALL'] + Env().discriminants
        if Env().target.os.name == 'vxworks6':
            self.discs.append('vxworks')

        if options.discs:
            self.discs += options.discs.split(',')

        if options.with_gdb:
            # Serialize runs and disable gprof
            options.mainloop_jobs = 1
            options.with_gprof = False

        # Read discriminants from testsuite.tags
        # The file testsuite.tags should have been generated by
        # AWS 'make setup'
        try:
            with open('testsuite.tags') as tags_file:
                self.discs += tags_file.read().strip().split()
        except IOError:
            sys.exit("Cannot find testsuite.tags. Please run make setup")

        if options.from_build_dir:
            os.environ["ADA_PROJECT_PATH"] = os.getcwd()
            # Read makefile.setup to set proper build environment
            c = MakeVar('../makefile.setup')
            os.environ["PRJ_BUILD"] = c.get(
                "DEBUG", "true", "Debug", "Release")
            os.environ["PRJ_XMLADA"] = c.get(
                "XMLADA", "true", "Installed", "Disabled")
            os.environ["PRJ_LAL"] = c.get(
                "LAL", "true", "Installed", "Disabled")
            os.environ["PRJ_LDAP"] = c.get(
                "LDAP", "true", "Installed", "Disabled")
            os.environ["PRJ_SOCKLIB"] = c.get("NETLIB")
            os.environ["SOCKET"] = c.get("SOCKET")
            os.environ["LIBRARY_TYPE"] = "static"
            # from-build-dir only supported on native platforms
            os.environ["PLATFORM"] = "native"
            # Add current tools in from of PATH
            os.environ["PATH"] = os.getcwd() + os.sep + ".." + os.sep \
                + ".build" + os.sep + os.environ["PLATFORM"] \
                + os.sep + os.environ["PRJ_BUILD"].lower() \
                + os.sep + "static" + os.sep + "tools" \
                + os.pathsep + os.environ["PATH"]

        logging.debug(
            "Running the testsuite with the following discriminants: %s"
            % ", ".join(self.discs))

        # Add current directory in PYTHONPATH (to find test_support.py)
        Env().add_search_path('PYTHONPATH', os.getcwd())
        os.environ["TEST_CONFIG"] = os.path.join(os.getcwd(), 'env.dump')

        Env().testsuite_config = options
        Env().store(os.environ["TEST_CONFIG"])

        # Save discriminants
        with open(options.output_dir + "/discs", "w") as discs_f:
            discs_f.write(" ".join(self.discs))

    def start(self, tests, show_diffs=False, old_result_dir=None):
        """Start the testsuite"""
        # Generate the testcases list
        if tests:
            # tests parameter can be a file containing a list of tests
            if len(tests) == 1 and os.path.isfile(tests[0]):
                with open(tests[0]) as _list:
                    tests = [t.strip().split(':')[0] for t in _list]
            else:
                # user list of tests, ignore tailing / to be able to use
                # file completion
                tests = [t.rstrip('/') for t in tests]
        else:
            # Get all tests.py
            tests = [os.path.dirname(t) for t in sorted(glob('*/test.py'))]

        if not Env().testsuite_config.with_Z999:
            # Do not run Z999 test
            tests = [t for t in tests if t != 'Z999_xfail']

        test_metrics = {'total': len(tests)}

        # Run the main loop
        collect_result = generate_collect_result(
            options=self.options,
            output_diff=show_diffs,
            metrics=test_metrics)
        run_testcase = generate_run_testcase('run-test', self.discs,
                                             Env().testsuite_config)
        MainLoop(tests, run_testcase, collect_result,
                 Env().testsuite_config.mainloop_jobs)

        if self.options.retry_threshold > 0:
            # Set skip if ok and run the testsuite if mainloop_jobs set to 1
            # to avoid parallelism problems on the tests that have previously
            # failed.
            if test_metrics['failed'] < self.options.retry_threshold:
                logging.warning("%d tests have failed (threshold was %d)."
                                " Retrying..."
                                % (test_metrics['failed'],
                                   self.options.retry_threshold))

                # Regenerate collect_result function
                self.options.skip_if_ok = True
                self.options.skip_if_dead = True
                collect_result = generate_collect_result(
                    options=self.options,
                    output_diff=show_diffs,
                    metrics=test_metrics)
                MainLoop(tests, run_testcase, collect_result, 1)
            else:
                logging.error("Too many errors")

        # Write report
        ReportDiff(self.options.output_dir,
                   self.options.old_output_dir).txt_image(
                       self.options.report_file)


def run_testsuite():
    """Main: parse command line and run the testsuite"""
    main = Main(formatter='%(message)s', add_targets_options=True)
    add_mainloop_options(main, extended_options=True)
    add_run_test_options(main)
    main.add_option("--with-Z999", dest="with_Z999",
                    action="store_true", default=False,
                    help="Add a test that always fail")
    main.add_option("--view-diffs", dest="view_diffs", action="store_true",
                    default=False, help="show diffs on stdout")
    main.add_option("--diffs", dest="view_diffs", action="store_true",
                    default=False, help="Alias for --view-diffs")
    main.add_option("--with-gprof", dest="with_gprof", action="store_true",
                    default=False, help="Generate profiling reports")
    main.add_option("--with-gdb", dest="with_gdb", action="store_true",
                    default=False, help="Run with gdb")
    main.add_option("--with-valgrind", dest="with_valgrind",
                    action="store_true", default=False,
                    help="Run with valgrind")
    main.add_option("--old-result-dir", type="string",
                    help="Old result dir")
    main.add_option("--from-build-dir", dest="from_build_dir",
                    action="store_true", default=False,
                    help="Run testsuite from local build (in repository)")
    main.add_option('--retry-when-errors-lower-than', dest='retry_threshold',
                    metavar="MAX_FAILED", default=0, type=int,
                    help="Retry the test that have failed if the number of "
                    "errors if lower than MAX_FAILED")
    main.parse_args()

    run = Runner(main.options)
    run.start(main.args, show_diffs=main.options.view_diffs)

if __name__ == "__main__":
    # Run the testsuite
    run_testsuite()
