#!/usr/bin/env python

# Word(Character) Error Rate, also gives the alignment infomation.
# Author: XiaoRui Wang

import sys, copy, getopt, re, os.path, math

# Cost of alignment types
SUB_COST = 3
DEL_COST = 3
INS_COST = 3

CRT_ALIGN = 0
SUB_ALIGN = 1
DEL_ALIGN = 2
INS_ALIGN = 3
END_ALIGN = 4


align_name = ['crt', 'sub', 'del', 'ins', 'end']

def getbasename(filename):
    global keepext
    p, n = os.path.split(filename)
    if not keepext:
        n, e = os.path.splitext(n)
    return n

def removetag(w):
    if not w:
        return ''
    p = w.split(',')
    return p[-1]

class WerStat:
    def __init__(self):
        self.reset()

    def reset(self):
        self.r = 0
        self.s = 0
        self.d = 0
        self.i = 0
        self.sen = 0
        self.errsen = 0

    def accumulate(self, r, s, d, i):
        self.r += r
        self.s += s
        self.d += d
        self.i += i
        self.sen += 1
        if (s+d+i) > 0:
            self.errsen += 1

    def computerwer(self):
        suberr = self.s * 100.0 / self.r
        delerr = self.d * 100.0 / self.r
        inserr = self.i * 100.0 / self.r
        self.e = self.s + self.d + self.i
        self.wer = self.e * 100.0 / self.r

    def printwer(self):
        print 'sub%6d del%6d ins%6d ref%6d' % (self.s, self.d, self.i, self.r)
        suberr = self.s * 100.0 / self.r
        delerr = self.d * 100.0 / self.r
        inserr = self.i * 100.0 / self.r
        wer = (self.s+self.d+self.i) * 100.0 / self.r
        print 'sub%6.2f del%6.2f ins%6.2f wer%6.2f' % (suberr, delerr, inserr, wer)

    def printser(self):
        print 'total sentence %d ser %.2f' % (self.sen, (self.errsen * 100.0 / self.sen))

def print_senwer(x, r, s, d, i):
    print '%s sub %2d del %2d ins %2d ref %d wer %.2f' \
                    % (x, s, d, i, r, ((s+d+i)*100.0/ r))

class entry:
    'Alignment chart entry, contains cost and align-type'

    def __init__(self, cost = 0, align = CRT_ALIGN):
        self.cost = cost
        self.align = align

def getidx(name):
    global keepext
    name = name.strip().split()[0]
    name = name.split('\\')[-1]
    name = name.split('/')[-1]
    index = name
    if not keepext:
        (index, ext) = os.path.splitext(index)
    return index

def getspk(name):
    name = name.split('_')
    return '_'.join(name[:-1])

def distance(ref, hyp):
    ref_len = len(ref)
    hyp_len = len(hyp)
    #print hyp_len

    chart = []
    for i in range(0, ref_len + 1):
        chart.append([])
        for j in range(0, hyp_len + 1):
            chart[-1].append(entry(i * j, CRT_ALIGN))

    # Initialize the top-most row in alignment chart, (all words inserted).
    for i in range(1, hyp_len + 1):
        chart[0][i].cost = chart[0][i - 1].cost + INS_COST;
        chart[0][i].align = INS_ALIGN
    # Initialize the left-most column in alignment chart, (all words deleted).
    for i in range(1, ref_len + 1):
        chart[i][0].cost = chart[i - 1][0].cost + DEL_COST
        chart[i][0].align = DEL_ALIGN

    # Fill in the rest of the chart
    for i in range(1, ref_len + 1):
        for j in range(1, hyp_len + 1):
            min_cost = 0
            min_align = CRT_ALIGN
            if hyp[j - 1] == ref[i - 1]:
                min_cost = chart[i - 1][j - 1].cost
                min_align = CRT_ALIGN
            else:
                min_cost = chart[i - 1][j - 1].cost + SUB_COST
                min_align = SUB_ALIGN

            del_cost = chart[i - 1][j].cost + DEL_COST
            if del_cost < min_cost:
                min_cost = del_cost
                min_align = DEL_ALIGN

            ins_cost = chart[i][j - 1].cost + INS_COST
            if ins_cost < min_cost:
                min_cost = ins_cost
                min_align = INS_ALIGN

            chart[i][j].cost = min_cost
            chart[i][j].align = min_align

    crt = sub = ins = det = 0
    i = ref_len
    j = hyp_len
    alignment = []
    while i > 0 or j > 0:
        #if i < 0 or j < 0:
            #break;
        if chart[i][j].align == CRT_ALIGN:
            alignment.append((i, j, CRT_ALIGN))
            i -= 1
            j -= 1
            crt += 1
        elif chart[i][j].align == SUB_ALIGN:
            alignment.append((i, j, SUB_ALIGN))
            i -= 1
            j -= 1
            sub += 1
        elif chart[i][j].align == DEL_ALIGN:
            alignment.append((i, j, DEL_ALIGN))
            i -= 1
            det += 1
        elif chart[i][j].align == INS_ALIGN:
            alignment.append((i, j, INS_ALIGN))
            j -= 1
            ins += 1

    total_error = sub + det + ins

    alignment.reverse()
    return (total_error, crt, sub, det, ins, alignment)
    
def wordrepl(matchobj):
#	return ' '+matchobj.group(0)+' '
	s = ' '
	for x in matchobj.group(0):
		s = s + x + ' '
	return s	
    
def read_sentences(filename, iscn=False):
    map = {}
    tmpdata = [x.split() for x in open(filename).readlines()]
    data = []
    # deal with multiwords
    for x in tmpdata:
        if len(x) == 0:
            continue
        if len(x) == 1:
            data.append(x[:])
            continue
        tmp = [removetag(w) for w in x[1:]]
        s = ' '.join(tmp)
        s = s.replace('_', ' ')
        s = s.replace('</s>', ' ')
        s = s.replace('<s>', ' ')
        s = s.replace('<aux>', ' ')
        data.append(s.split())
        data[-1].insert(0, x[0])

    for x in data:
        if len(x) == 0:
            continue

        index = getidx(x[0])
        ### index = re.sub(r'\.[^\.]*$', '', index)
        if index in map:
            sys.stderr.write('Duplicate index [%s] in file %s\n'
                    % (index, filename))
            sys.exit(-1)
        if len(x) == 1:
            map[index] = []
        else:
            tmp = x[1:]
            if iscn:
                #tmp = unicode(' '.join(tmp), 'utf8')
                ##tmp = tmp.encode('utf8')
                #tmp = re.sub(r'\s', '', tmp)
                ##print tmp.encode('utf8'),'\n'
                tmp2 = [unicode(t, 'utf8') for t in tmp]
                tmp = []
               	patt = '[^\da-zA-Z\.\-\']+'
                for x in tmp2:
                	#print x.encode('utf8')
                	x = re.sub(patt, wordrepl, x)
                	#x = re.sub(r'^\s+', '', x);
                	#print x.encode('utf8')
                	tmp.extend(x.split())
                tmp = [x.lower() for x in tmp]
                #print (' '.join(tmp)).encode('utf8'),'\n'
            else:
                tmp = [x.lower() for x in tmp]
            map[index] = tmp
    return map

def readppl(filename):
    seenmap = {}
    senstr = ''

    sen_start = False
    for x in open(filename).xreadlines():
        x = x.strip()
        words = x.split()
        if not words:
            continue
    
        if words[0] == 'file':
            if senstr:
                seenmap[senstr] = strmap[:]
            break


        if not sen_start:
            if words[0] == 'p(':
                if senstr:
                    seenmap[senstr] = strmap[:]

                sen_start = True
                senstr = ''
                strmap = []
    
        if sen_start == True:
            if words[0] != 'p(':
                sen_start = False
            else:
                #print words[6]
                seen = True
                if words[6] == '[OOV]':
                    seen = False
                else:
                    order = int(words[6][1])
                    if order == 3:
                        seen = True
                    else:
                        seen = False

                if not words[1].startswith('<'):
                    senstr += words[1]
                    if seen:
                        for x in range(len(words[1]) / 2):
                            strmap.append(1)
                    else:
                        for x in range(len(words[1]) / 2):
                            strmap.append(0)

    unicode_seenmap = {}
    for x in seenmap:
        unicode_seenmap[unicode(x, 'utf8')] = seenmap[x]
    return unicode_seenmap

def get_wer(ref, hyp, idx):
    total_stat = WerStat()
    lenwer = {}

    if len(idx):
        local_idx = []
        for x in idx:
            if x not in hyp:
                sys.stderr.write('Warning, empty hyperthesis %s\n' % x)
                total_stat.accumulate(len(ref[x]), 0, len(ref[x]), 0)
            else:
                local_idx.append(x)
    else:
        local_idx = hyp.keys()
        local_idx.sort()

    unseen_tot = 0
    unseen_err = 0

    speaker_wer = {}
    enpatt = '[\da-zA-Z\.\-\']+'
    total_enwords = 0
    total_enwords_correct = 0
    err_1m = 0.0
    err_2m = 0.0
    all_aligninfo = {}
    for x in local_idx:
        if x not in ref:
            sys.stderr.write('Error, no reference for %s\n' % x)
            continue
            ### sys.exit(-1)

        aligninfo = distance(ref[x], hyp[x])
        all_aligninfo[x] = aligninfo
        if iscn:
            for i in range(len(ref[x])):
                if re.match(enpatt, ref[x][i]):
                    total_enwords += 1
                    for y in aligninfo[-1]:
                        if y[0] == i+1:
                            if y[2] == CRT_ALIGN:
                                j = y[1]-1
                                #print ref[x][i], hyp[x][j]
                                total_enwords_correct += 1
                                break

        l = len(ref[x])
        total_stat.accumulate(l, aligninfo[2], aligninfo[3], aligninfo[4])
        if l not in lenwer:
            lenwer[l] = WerStat()
        lenwer[l].accumulate(l, aligninfo[2], aligninfo[3], aligninfo[4])

        if perspeaker:
            spk = getspk(x)
            if spk not in speaker_wer:
                speaker_wer[spk] = WerStat()
            speaker_wer[spk].accumulate(len(ref[x]), aligninfo[2], aligninfo[3], aligninfo[4])

        # Get seen and unseen stat
        if seenmap:
            if ref[x] not in seenmap:
                for y in seenmap:
                    if ref[x] == y:
                        print 'YES'
                sys.stderr.write('Error, sentence\n%s\t"%s"\nnot in seenmap\n' \
                        % (x, ref[x].encode('utf8')))
                sys.exit(-1)
            m = seenmap[ref[x]]
            for y in m:
                if y == 0:
                    unseen_tot += 1
            for a in aligninfo[-1]:
                if a[2] != CRT_ALIGN:
                    if m[a[0] - 1] == 0: # We must substract 1
                        unseen_err += 1

        # print each sentence's wer
        if printsen:
            print_senwer(x, len(ref[x]), aligninfo[2], aligninfo[3], aligninfo[4])

    total_stat.printwer()
    total_stat.printser()

    if iscn and total_enwords > 0:
        print 'Total english/digit words: %d, error ratio: %.2f\n' % (total_enwords, ((total_enwords - total_enwords_correct) * 100.0 / total_enwords))

    if perlen:
        tmp = lenwer.keys()
        tmp.sort()
        for x in tmp:
            ### if x < 21:
            ###     continue

            print '-' * 60
            print x
            lenwer[x].printwer()
            lenwer[x].printser()

    if perspeaker:
        speakers = speaker_wer.keys()
        speakers.sort()
        for x in speakers:
            print '%s:' % x
            speaker_wer[x].printwer()
            speaker_wer[x].printser()

    if seenmap:
        seen_wer = (total_stat.s + total_stat.d + total_stat.i - unseen_err) * 100.0 / (total_stat.r - unseen_tot)
        unseen_wer = unseen_err * 100.0 / unseen_tot
        print ''
        #print 'seen number', total_ref_len - unseen_tot
        print 'seen wer', seen_wer
        #print 'unseen number', unseen_tot
        print 'unseen wer', unseen_wer

    return all_aligninfo

def count_error(aligninfo):
    e = 0
    e += aligninfo[2]
    e += aligninfo[3]
    e += aligninfo[4]
    return e

def writehtml(filename, idx):
    global ref, hyp, hyp2, ali, ali2
    f = open(filename, 'wt')
    f.write('<html>\n')
    f.write('<head>\n')
    f.write('<meta charset="UTF-8">\n')
    f.write('</head>\n')
    f.write('<body>\n')

    for x in idx:
        f.write('%s<br>\n' % x)
        #for a in ali[x][-1]:
        #    print a
        #print ref[x]
        #print hyp[x]
        for a in ali[x][-1]:
            if a[-1] == INS_ALIGN:
                f.write('&nbsp;&nbsp;')
            elif a[-1] == CRT_ALIGN:
                f.write('%s' % ref[x][a[0]-1].encode('utf8'))
            elif a[-1] == SUB_ALIGN:
                f.write('<font style="background-color: #00ff80">%s' % ref[x][a[0]-1].encode('utf8'))
                l1 = len(ref[x][a[0]-1].encode('utf8'))
                l2 = len(hyp[x][a[1]-1].encode('utf8'))
                #print l1, l2, a
                for ii in range(l2 - l1):
                    f.write('&nbsp;')
                f.write('</font>')
            elif a[-1] == DEL_ALIGN:
                f.write('<font style="background-color: #ff8000">%s</font>' % ref[x][a[0]-1].encode('utf8'))
        f.write('<br>\n')

        for a in ali[x][-1]:
            if a[-1] == INS_ALIGN:
                f.write('<font style="background-color: #ff0000">%s</font>' % hyp[x][a[1]-1].encode('utf8'))
            elif a[-1] == CRT_ALIGN:
                f.write('%s' % hyp[x][a[1]-1].encode('utf8'))
            elif a[-1] == SUB_ALIGN:
                f.write('<font style="background-color: #00ff80">%s</font>' % hyp[x][a[1]-1].encode('utf8'))
            elif a[-1] == DEL_ALIGN:
                f.write('&nbsp;&nbsp;')
        f.write('<br>\n')

        if ali2:
            for a in ali2[x][-1]:
                if a[-1] == INS_ALIGN:
                    f.write('<font style="background-color: #ff0000">%s</font>' % hyp2[x][a[1]-1].encode('utf8'))
                elif a[-1] == CRT_ALIGN:
                    f.write('%s' % hyp2[x][a[1]-1].encode('utf8'))
                elif a[-1] == SUB_ALIGN:
                    f.write('<font style="background-color: #00ff80">%s</font>' % hyp2[x][a[1]-1].encode('utf8'))
                elif a[-1] == DEL_ALIGN:
                    f.write('&nbsp;&nbsp;')
            f.write('<br>\n')
        f.write('<br>\n')

    f.write('</body>\n')
    f.write('</html>\n')

def count_wer(ali, idx):
    global ref

    r, s, d, i = 0, 0, 0, 0
    for x in idx:
        r += len(ref[x])
        s += ali[x][2]
        d += ali[x][3]
        i += ali[x][4]

    return s * 100.0 / r, d * 100.0 / r, i * 100.0 / r, r

def write_ali_count(hyp, ali, prefix):
    global ref
    s = {}
    d = {}
    i = {}

    for x in ali:
        for y in ali[x][-1]:
            if y[-1] == SUB_ALIGN:
                r = ref[x][y[0]-1]
                h = hyp[x][y[1]-1]
                if (r, h) not in s:
                    s[(r, h)] = 1
                else:
                    s[(r, h)] += 1
            elif y[-1] == DEL_ALIGN:
                r = ref[x][y[0]-1]
                if r not in d:
                    d[r] = 1
                else:
                    d[r] += 1
            elif y[-1] == INS_ALIGN:
                h = hyp[x][y[1]-1]
                if h not in i:
                    i[h] = 1
                else:
                    i[h] += 1

    tops = []
    for x in s:
        tops.append((s[x], x))
    tops.sort(reverse=True)

    topd = []
    for x in d:
        topd.append((d[x], x))
    topd.sort(reverse=True)

    topi = []
    for x in i:
        topi.append((i[x], x))
    topi.sort(reverse=True)

    f = open('%s_sub.txt' % prefix, 'wt')
    for x in tops:
        f.write('%s\t%s\t%d\n' % (x[1][0].encode('utf8'), x[1][1].encode('utf8'), x[0]))
    f.close()
    f = open('%s_del.txt' % prefix, 'wt')
    for x in topd:
        f.write('%s\t%d\n' % (x[1].encode('utf8'), x[0]))
    f.close()
    f = open('%s_ins.txt' % prefix, 'wt')
    for x in topi:
        f.write('%s\t%d\n' % (x[1].encode('utf8'), x[0]))
    f.close()


def usage():
    'Print usage'
    print ('''Usage:
    -r, --ref <ref-file>        reference file.
    -h, --hyp <hyp-file>        hyperthesis file.
    -c, --chinese               CER for Chinese.
    -i, --index                 index file, only use senteces have these index.
    -s, --sentence              print each sentence info.
    -p, --ppl                   PPL file.
    --help                      print usage.
    --speaker                   print wer per speaker.
    ''')

if __name__ == '__main__':
    try:
        options, args = getopt.getopt(sys.argv[1:], 'r:h:ci:sp:',
                ['ref=', 'hyp=', 'chinese', 'index=', 'sentence', 'ppl', 'help', \
                        'speaker', 'hyp2=', 'length', 'pattern=', 'html=',
                        'keep-ext'])
    except getopt.GetoptError:
        usage()
        sys.exit(-1)
    
    reffile = hypfile = idxfile = pplfile = hypfile2 = None
    iscn = False
    printsen = False
    perspeaker = False
    perlen = False
    seenmap = {}
    pattern = ''
    html = ''
    keepext = False

    for o, a in options:
        if o in ('--help',):
            usage()
            sys.exit(0)

        if o in ('-r', '--ref'):
            reffile = a
        elif o in ('-h', '--hyp'):
            hypfile = a
        elif o in ('-c', '--chinese'):
            iscn = True;
        elif o in ('-i', '--index'):
            idxfile = a
        elif o in ('-p', '--ppl'):
            pplfile = a
        elif o in ('-s', '--sentence'):
            printsen = True
        elif o in ('--keep-ext',):
            keepext = True
        elif o in ('--speaker',):
            perspeaker = True
        elif o in ('--length',):
            perlen = True
        elif o in ('--hyp2',):
            hypfile2 = a
        elif o in ('--pattern',):
            pattern = a
        elif o in ('--html',):
            html = a

    if not (reffile and hypfile):
        usage()
        sys.exit(-1)
    if pplfile and not iscn:
        sys.stderr.write('Error, -p can use with -c only\n')
        sys.exit(-1)

    if pplfile:
        seenmap = readppl(pplfile)
        #for x in seenmap:
        #    print '"%s"' % x
        #    for y in seenmap[x]:
        #        print y,
        #    print ''

    ref = read_sentences(reffile, iscn)
    hyp = read_sentences(hypfile, iscn)

    if idxfile:
        idx = [getidx(x) for x in open(idxfile).readlines()]
    else:
        idx = hyp.keys()
    idx.sort()
    if pattern != '':
        print 'pattern' ,pattern
        print pattern
        tmp = []
        repattern = re.compile(pattern)
        for x in idx:
            if repattern.search(x):
                tmp.append(x)
        idx = tmp[:]

    basename = getbasename(hypfile)
    print '-' * 60
    print basename
    ali = get_wer(ref, hyp, idx)
    print ''
    ali2 = False
    if html:
        writehtml(html, idx)

    if hypfile2:
        hyp2 = read_sentences(hypfile2, iscn)
        basename = getbasename(hypfile2)
        print '-' * 60
        print basename
        ali2 = get_wer(ref, hyp2, idx)
        print ''

        same_res = []
        same_wer = []
        better = []
        worse = []

        local_idx = idx
        if not local_idx:
            local_idx = hyp.keys()
            local_idx.sort()

        lenwer = {}
        for x in local_idx:
            l = len(ref[x])
            if l not in lenwer:
                lenwer[l] = (WerStat(), WerStat())
            if x not in hyp:
                lenwer[l][0].accumulate(l, 0, l, 0)
            if x not in hyp2:
                lenwer[l][1].accumulate(l, 0, l, 0)

            if x not in hyp or x not in hyp2:
                continue
            lenwer[l][0].accumulate(l, ali[x][2], ali[x][3], ali[x][4])
            lenwer[l][1].accumulate(l, ali2[x][2], ali2[x][3], ali2[x][4])


            if hyp[x] == hyp2[x]:
                same_res.append(x)
            else:
                e1 = count_error(ali[x])
                e2 = count_error(ali2[x])
                if e1 == e2:
                    same_wer.append(x)
                elif e1 < e2:
                    worse.append(x)
                else:
                    better.append(x)
        print 'Total Sentence:', len(local_idx)
        print 'Same Result:', len(same_res), ('%.2f' % (100.0 * len(same_res) / len(local_idx)))
        print 'Better Result:', len(better), ('%.2f' % (100.0 * len(better) / len(local_idx)))
        print 'Worse Result:', len(worse), ('%.2f' % (100.0 * len(worse) / len(local_idx)))

        writehtml('better.html', better)
        writehtml('worse.html', worse)
        writehtml('same.html', same_wer)

        print '\nformat: SUB DEL INS TOT'
        print 'Better:'
        s, d, i, r = count_wer(ali, better)
        print 'Reference count', r
        print 'sentence count', len(better)
        print 'Result1: %.2f\t%.2f\t%.2f\t%.2f' % (s, d, i, s + d + i)
        s, d, i, r = count_wer(ali2, better)
        print 'Result2: %.2f\t%.2f\t%.2f\t%.2f' % (s, d, i, s + d + i)

	if len(worse) > 0:
            print 'Worse:'
            s, d, i, r = count_wer(ali, worse)
            print 'Reference count', r
            print 'sentence count', len(worse)
            print 'Result1: %.2f\t%.2f\t%.2f\t%.2f' % (s, d, i, s + d + i)
            s, d, i, r = count_wer(ali2, worse)
            print 'Result2: %.2f\t%.2f\t%.2f\t%.2f' % (s, d, i, s + d + i)
        else:
            print 'Worse: 0'

        write_ali_count(hyp, ali, 'result1_stat')
        write_ali_count(hyp2, ali2, 'result2_stat')

        tmp = lenwer.keys()
        tmp.sort()
        lenwer[10000] = [WerStat(), WerStat()]
        for x in tmp:
            s1 = lenwer[x][0]
            s2 = lenwer[x][1]
            lenwer[10000][0].accumulate(s1.r, s1.s, s1.d, s1.i)
            lenwer[10000][1].accumulate(s2.r, s2.s, s2.d, s2.i)
        lenwer[10000][0].computerwer()
        lenwer[10000][1].computerwer()

        for x in tmp[:-1]:
            lenwer[x][0].computerwer()
            lenwer[x][1].computerwer()
            print '%d\t%.2f\t%.2f\t%.2f\t%.2f\t%d\t%d' % (x, lenwer[x][0].wer, lenwer[x][1].wer, \
                    (lenwer[x][0].e * 100.0 / lenwer[10000][0].e), \
                    (lenwer[x][1].e * 100.0 / lenwer[10000][1].e),
                    lenwer[x][0].e, \
                    lenwer[x][1].e, \
                    )
