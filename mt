#!/usr/bin/python3

import argparse
import pty
import os
import sys
import fcntl
import time
import termios
import shutil

from PIL import Image, ImageDraw, ImageFont



def filter_console_output(output):
    """
    Removes terminal ascii escape codes from output..
    @todo: output colors, respect cursor movement (even tho its probably useless option)
    """
    output_filtered = ''
    started = False
    # these should be all the letters which are ending a escape code..
    escape_code = ''
    ascii_escape_code_terminators = ('m', 'A', 'B', 'C', 'D', 'J', 'K', 'H', 'f', 's', 'u',  'h', 'l', 'r', 'n')
    # ascii_escape_code_terminators = [ ord(c) for c in terminators_letters ]
    for char in output:
        if started:
            escape_code += char

        # order of these 3 if's is (almost probably..) not accidential and required!!
        if char == chr(27):
            started = True

        if not started:
            output_filtered += char  # @todo: this is slow.. because list appending, right?

        if started and char in ascii_escape_code_terminators:
            started = False
            print(escape_code, end=' ')
            escape_code = ''

    print()

    return output_filtered


def mock_terminal(process, arguments=[], size=(150, 130)):
    master, slave = pty.openpty()
    pid, fd = pty.fork()
    termios.tcsetwinsize(master, size)
    print('size:', termios.tcgetwinsize(master))

    if pid == 0:  # this happens in child
        # close(m);
        # setsid() #;/* create a new process group */
        os.dup2(slave, 0)
        os.dup2(slave, 1)
        os.dup2(slave, 2)

        # @todo: get path for the process
        process = shutil.which(process)
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


def output_to_picture(output, filename, color=(0,0,0), font_path='./fonts/iosevka-regular.ttf', backend='pygame'):
    if backend == 'pygame':
        output_to_picture_pygame(output, filename, color, font_path)
    elif backend == 'pillow':
        output_to_picture_pillow(output, filename, color, font_path)


def pillow_get_size_of_text(font, text):
    x, y, width, height = ImageDraw.Draw(Image.new("RGB", (1,1))).textbbox((0,0), text, font=font)
    height -= y
    return width, height

def output_to_picture_pillow(output, filename, color, font_path):
    font = ImageFont.truetype(font_path, 40)
    width, height = pillow_get_size_of_text(font, output)
    text = Image.new("RGBA", (width, height), (255, 255, 255, 0))
    ImageDraw.Draw(text).text((0, 0), output, font=font, fill=color+(255,))
    text.save(filename)


def output_to_picture_pygame(output, filename, color, font_path):
    import pygame  # it seems I can do init on each function use without any issues
    pygame.init()
    pygame.font.init()
    # print('unicode supported:', hasattr(pygame.font, "UCS4"))

    split = output.splitlines()
    columns, rows = max([ len(line) for line in split ]), len(split)

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


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('command', nargs='+', help='command with arguments output of you want to render')

    parser.add_argument('--filename', default='output.png', help='name of the file to save output render to')

    parser.add_argument('--width',  help= 'width of the spawned terminal', type=int)
    parser.add_argument('--height', help='height of the spawned terminal', type=int)

    parser.add_argument('--fontpath', help='path of the font to use')
    parser.add_argument('--font',     help='name of the system font to use, overrides fontpath setting')
    parser.add_argument('--fontsize', default=40, type=int)
    # parser.add_argument('--color')     help=  @todo

    parser.add_argument('--backend', default='pygame', choices=['pygame', 'pillow'])

    args = parser.parse_args()

    width, height = termios.tcgetwinsize(sys.stdout)
    if args.width:
        width = args.width
    if args.height:
        height = args.height

    command, arguments = args.command[0], args.command[1:]
    output = mock_terminal(command, arguments, (width, height))
    print(output)

    output_to_picture(output, args.filename, color=(255,255,255), backend=args.backend)
    output_to_picture(output, 'black.png', backend=args.backend)

    # output_to_picture(output, filename='black.png')
    # output = mock_terminal('/usr/bin/bat', [__file__])
    # output_to_picture(output, filename='black.png')
    # output_to_picture(output, color=(255,255,255))

if __name__ == '__main__':
    main()
