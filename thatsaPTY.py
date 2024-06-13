#!/usr/bin/python3

import pty
import os
import sys
import fcntl
import time
import termios
import pygame


def filter_console_output(output):
    """
    Removes terminal ascii escape codes from output..
    @todo: output colors, respect cursor movement (even tho its probably useless option)
    """
    output_filtered = []
    started = False
    # these should be all the letters which are ending a escape code..
    ascii_escape_code_terminators = [ 'm', 'A', 'B', 'C', 'D', 'J', 'K', 'H', 'f', 's', 'u',  'h', 'l', 'r', 'n' ]
    # ascii_escape_code_terminators = [ ord(c) for c in terminators_letters ]
    for char in output:
        if started:
            pass

        # order of these 3 if's is (almost probably..) not accidential and required!!
        if char == chr(27):
            started = True

        if not started:
            output_filtered.append(char) # @todo: this is slow.. because list appending, right?

        if char in ascii_escape_code_terminators:
            started = False

    return ''.join(output_filtered)


def mock_terminal(process, arguments=[], size=(150, 130)):
    master, slave = pty.openpty()
    pid, fd = pty.fork()
    termios.tcsetwinsize(master, size)

    if pid == 0:  # this happens in child
        # close(m);
        # setsid() #;/* create a new process group */
        os.dup2(slave, 0)
        os.dup2(slave, 1)
        os.dup2(slave, 2)

        os.execl(process, process, *arguments)
        sys.exit(1)

    # this happens only in parent process
    print('started process with id:', pid)
    fcntl.fcntl(master, fcntl.F_SETFL, os.O_NONBLOCK)

    output = b''
    with os.fdopen(master, 'rb') as f:
        while True:
            try:
                os.waitpid(pid, os.WNOHANG)
            except ChildProcessError:
                break
            part = f.read()
            time.sleep(0.01)
            if part == None:
                continue
            output += part

    print(f'read {len(output)} bytes')
    return filter_console_output(output.decode().strip('\n'))


_pygame_initialized = False
def output_to_picture(output, size=None, color=(0,0,0), font_path='./fonts/iosevka-regular.ttf', filename='output.png'):
    global _pygame_initialized
    if not _pygame_initialized:
        pygame.init()
        pygame.font.init()
        print('unicode supported:', hasattr(pygame.font, "UCS4"))
        _pygame_initialized = True

    if size == None:
        split = output.splitlines()
        columns, rows = max([ len(line) for line in split ]), len(split)
    else:
        columns, rows = size

    print(f'set dimensions to: {columns},{rows}')

    font = pygame.font.Font(font_path, 40)

    text_surfaces = [ font.render(line, True, color) for line in split ]
    heights_list = [surface.get_height() for surface in text_surfaces]

    max_width = max(text_surfaces, key=lambda x: x.get_width()).get_width()
    height_sum = sum(heights_list)

    output_surface = pygame.Surface((max_width, height_sum), flags=pygame.SRCALPHA)

    # lines can have variable height (for some reason..), so we have to check height of each line
    current_y = 0
    for surface, surface_height in zip(text_surfaces, heights_list):
        output_surface.blit(surface, (0, current_y))
        current_y += surface_height

    pygame.image.save(output_surface, filename)

output = mock_terminal('/usr/bin/bat', [__file__])
output_to_picture(output, filename='black.png')
output_to_picture(output, color=(255,255,255))
