import sys, os
import subprocess

def main() -> int:
    '''
    Main entry point for running commands in the package.
    '''
    argCount = len(sys.argv)
    if argCount < 2:
        print('No arguments provided. Use -h or --help for help.')
        return 1
    if sys.argv[1] == '-h' or sys.argv[1] == '--help':
        print('Usage: python -m materialxusd <command> [options] where command is: m2u, pmtlx, or getmtlx')

    # Check if the command is valid
    cmdArgs = sys.argv[1:]
    if cmdArgs[0] == 'm2u':
        cmdArgs[0] = 'mtlx2usd.py'
    elif cmdArgs[0] == 'pmtlx':
        cmdArgs[0] = 'preprocess_mtlx.py'
    elif cmdArgs[0] == 'getmtlx':
        cmdArgs[0] = 'mtlxdownload.py'
    else:
        print('Unknown command specified:', cmdArgs[0])
        return 1
    
    # Build the command
    cmd = ' '.join(cmdArgs)
    packageLocation = os.path.dirname(__file__)
    cmd = sys.executable + ' ' + packageLocation + '/' + cmd
    print('Running command:', cmd)

    # Run the command
    return subprocess.call(cmd, shell=True)

if __name__ == '__main__':
    sys.exit(main())
