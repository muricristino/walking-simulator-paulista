import sys, json, xml.etree.ElementTree as ET
NS = {'c': 'http://www.collada.org/2005/11/COLLADASchema'}
def run(path):
    root = ET.parse(path).getroot()
    ctrls = {}
    for c in root.iter('{%s}controller' % NS['c']):
        skin = c.find('c:skin', NS)
        bsm = [float(x) for x in skin.find('c:bind_shape_matrix', NS).text.split()]
        srcs = {s.get('id'): s for s in skin.findall('c:source', NS)}
        joints_in = skin.find('c:joints', NS)
        jsrc = invsrc = None
        for i in joints_in.findall('c:input', NS):
            if i.get('semantic') == 'JOINT': jsrc = srcs[i.get('source')[1:]]
            if i.get('semantic') == 'INV_BIND_MATRIX': invsrc = srcs[i.get('source')[1:]]
        names = jsrc.find('c:Name_array', NS).text.split()
        f = [float(x) for x in invsrc.find('c:float_array', NS).text.split()]
        inv = [f[k*16:(k+1)*16] for k in range(len(f)//16)]
        ctrls[c.get('id')] = {'joints': names, 'inv': inv, 'bsm': bsm}
    out = {}
    for n in root.iter('{%s}node' % NS['c']):
        ic = n.find('c:instance_controller', NS)
        if ic is not None:
            out[n.get('name') or n.get('id')] = ctrls[ic.get('url')[1:]]
    return out
if __name__ == '__main__':
    d = run(sys.argv[1])
    if len(sys.argv) > 2:
        json.dump(d, open(sys.argv[2], 'w'))
    else:
        for k, v in d.items(): print(k, len(v['inv']), v['bsm'][:4])
