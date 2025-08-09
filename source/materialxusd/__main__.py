import sys, os
import subprocess
import argparse

def main() -> int:
    '''
    Main entry point for running commands in the package.
    '''
    parser = argparse.ArgumentParser(description='MaterialX / USD command line utilities.', add_help=False)
    parser.add_argument('option', nargs='?', help='Possible options: m2u, pmtlx, getmtlx, webpage, mxgl')
    args, remaining_args = parser.parse_known_args()

    option = args.option
      # If no option provided or help requested for main command, show help
    if option is None or option in ['-h', '--help']:
        parser.add_help = True
        parser.print_help()
        return 0
    
    if option == 'm2u':
        cmd = 'mtlx2usd.py'
    elif option == 'pmtlx':
        cmd = 'preprocess_mtlx.py'
    elif option == 'getmtlx':
        cmd = 'mtlxdownload.py'
    elif option == 'mxgl':
        cmd = 'mxglslrender.py'
    elif option == 'webpage':
        cmd = 'flask_app.py'
    else:
        print(f'Unknown option specified: {option}')
        parser.add_help = True
        parser.print_help()
        return 1
    
    # Build command with remaining arguments (for non-Flask commands)
    cmdArgs = [cmd] + remaining_args
    cmd = ' '.join(cmdArgs)
    packageLocation = os.path.dirname(__file__)
    cmd = sys.executable + ' ' + packageLocation + '/' + cmd
    print('Running command:', cmd)

    # Run the command and allow breaking with Ctrl+C / Cmd-C
    try:
        return subprocess.call(cmd, shell=True)
    except KeyboardInterrupt:
        print("\nProcess interrupted by user.")
        return 130  # Standard exit code for interrupted process

if __name__ == '__main__':
    sys.exit(main())
