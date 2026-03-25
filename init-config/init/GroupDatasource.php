<?php

declare(strict_types=1);

namespace App\Crudit\Datasource;

use Lle\CredentialBundle\Entity\Group;
use Lle\CruditBundle\Datasource\AbstractDoctrineDatasource;

class GroupDatasource extends AbstractDoctrineDatasource
{
    public function getClassName(): string
    {
        return Group::class;
    }
}
