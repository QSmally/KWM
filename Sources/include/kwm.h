
#ifndef KWM_INJECT_H
#define KWM_INJECT_H

void set_rules(const Rule new_rules[], size_t new_rules_size) {
    if (rules != NULL)
        free(rules);
    rules_size = new_rules_size;

    if (new_rules_size > 0) {
        size_t new_rules_bytes = sizeof(Rule) * new_rules_size;
        rules = malloc(new_rules_bytes);
        memcpy(rules, new_rules, new_rules_bytes);
    }
}

void kiosk_tile(Monitor* m) {
    unsigned int i, n, h, mw, my, ty;
    Client *c;

    for (n = 0, c = nexttiled(m->clients); c; c = nexttiled(c->next), n++);
    if (n == 0)
        return;

    if (n > m->nmaster)
        mw = m->nmaster ? m->ww * m->mfact : 0;
    else
        mw = m->ww;
    for (i = my = ty = 0, c = nexttiled(m->clients); c; c = nexttiled(c->next), i++)
        if (i < m->nmaster) {
            h = (m->wh - my) / (MIN(n, m->nmaster) - i);
            resize(c, m->wx, m->wy + my, mw - (2*c->bw), h - (2*c->bw), 0);
            if (my + HEIGHT(c) < m->wh)
                my += HEIGHT(c);
        } else {
            h = (m->wh - ty) / (n - i);
            resize(c, m->wx + mw, m->wy + ty, m->ww - mw - (2*c->bw), h - (2*c->bw), 0);
            if (ty + HEIGHT(c) < m->wh)
                ty += HEIGHT(c);
        }
}

#endif
