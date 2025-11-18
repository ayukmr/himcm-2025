import random
import numpy as np
import torch
from torch import nn
import torch.nn.functional as F

import csv

class Model(nn.Module):
    def __init__(self):
        super(Model, self).__init__()

        self.l1 = nn.Linear(19, 16)
        self.l2 = nn.Linear(16, 16)
        self.l3 = nn.Linear(16, 1)

    def forward(self, x):
        x = F.relu(self.l1(x))
        x = F.relu(self.l2(x))
        x = F.softplus(self.l3(x))

        return x

def load_data(path):
    with open(path) as f:
        reader = csv.DictReader(f)
        return list(filter(None, map(fmt, reader)))

keys = [
    'residential_elec_co2e',
    'residential_gas_co2e',
    'commercial_elec_co2e',
    'commercial_gas_co2e',
    'industry_elec_co2e',
    'industry_gas_co2e',
    'transport_gas_co2e',
    'transport_diesel_co2e'
]

def fmt(d):
    if 'state' in d and d['state'] not in ['CA', 'NV', 'AZ', 'OR']:
        return None

    co2e = [float(d[k]) if d[k] else None for k in keys if k in d]

    return (
        [
            float(d['latitude']),
            float(d['longitude']),
            float(d['average_dist'])
        ],
        [sum(co2e) / float(d['population'])] if None not in co2e and 'population' in d else None
    )

train = load_data('train.csv')
random.shuffle(train)

train = [d for d in train if d[1]]

print(f'{len(train)} rows')

def encode(x):
    lat, lon, dist = x

    lat -= 36.5
    lon -= -119.5

    out = [lat, lon, dist]

    for k in [1,2,4,8]:
        out += [
            np.sin(k * lat), np.cos(k * lat),
            np.sin(k * lon), np.cos(k * lon),
        ]

    return out

xs = np.array([encode(x) for x,_ in train])
x_mean = xs.mean(axis=0)
x_std = xs.std(axis=0) + 1e-8

def norm_x(x):
    return (encode(x) - x_mean) / x_std

ys = np.array([row[1] for row in train], dtype=float)
y_mean = ys.mean()
y_std = ys.std() + 1e-8

def norm_y(y):
    return (y - y_mean) / y_std

def denorm_y(yhat):
    return yhat * y_std + y_mean

def train_model(train):
    model = Model()
    optim = torch.optim.Adam(model.parameters(), lr=1e-4)
    loss_fn = nn.MSELoss()

    epochs = 500
    load = '⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'

    batch_size = 4

    for epoch in range(epochs):
        print(f'\r{load[(epoch // 5) % 10]} epoch {epoch + 1}', end='', flush=True)

        random.shuffle(train)

        for i in range(0, len(train), batch_size):
            batch = train[i:i+batch_size]

            xs_batch = torch.tensor(np.array([norm_x(x) for x, _ in batch]), dtype=torch.float32)
            ys_batch = torch.tensor(np.array([norm_y(y) for _, y in batch]), dtype=torch.float32)

            out = model(xs_batch)
            loss = loss_fn(out, ys_batch)

            loss.backward()
            optim.step()
            optim.zero_grad()

    print()

    return model

model = train_model(train)
torch.save(model.state_dict(), 'weights.pth')

# model = Model()
# model.load_state_dict(torch.load('weights.pth'))
# model.eval()

def eval_model(model, test):
    model.eval()
    total = 0.0

    with torch.no_grad():
        for xs, y in test:
            pred = model(torch.tensor(norm_x(xs), dtype=torch.float32).unsqueeze(0))
            y_norm = torch.tensor(norm_y(y), dtype=torch.float32).unsqueeze(0)
            total += F.mse_loss(pred, y_norm).item()

    test_loss = total / len(test)
    print(f'loss: {np.sqrt(test_loss) * y_std}')

eval_model(model, train)

sample = load_data('locs.csv')

new = [
    (
        xs,
        [
            denorm_y(
                model(torch.tensor(norm_x(xs), dtype=torch.float32).unsqueeze(0)).item()
            )
        ]
    )
    for xs, _ in sample
]

header = [
    'latitude',
    'longitude',
    'average_dist',
    'total_co2e_pc'
]

with open('pred.csv', 'w') as f:
    writer = csv.writer(f)
    writer.writerow(header)
    writer.writerows([row[0] + row[1] for row in new])
